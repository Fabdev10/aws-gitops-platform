from collections import defaultdict
from datetime import datetime, timezone
from os import getenv
from socket import gethostname
from threading import Lock
from time import monotonic, perf_counter
from uuid import uuid4

import boto3
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel

from app.settings import get_settings

START_TIME = monotonic()
settings = get_settings()
REQUEST_METRICS_LOCK = Lock()
REQUEST_COUNTS: dict[tuple[str, str, int], int] = defaultdict(int)
REQUEST_DURATION_MS: dict[tuple[str, str, int], float] = defaultdict(float)

CUSTOMER_METRICS_LOCK = Lock()
CUSTOMER_OPERATIONS: dict[str, int] = defaultdict(int)

class CustomerCreate(BaseModel):
    name: str
    email: str

class Customer(BaseModel):
    id: str
    name: str
    email: str
    created_at: str

class CustomerStore:
    def __init__(self):
        self._lock = Lock()
        self._in_memory_db: dict[str, dict] = {}
        self._db_initialized = False
        self._table = None

    def _get_table(self):
        if not self._db_initialized:
            table_name = get_settings().customers_table
            if table_name:
                try:
                    dynamodb = boto3.resource("dynamodb", region_name=get_settings().aws_region)
                    self._table = dynamodb.Table(table_name)
                except Exception:
                    self._table = None
            self._db_initialized = True
        return self._table

    def list_customers(self) -> list[dict]:
        table = self._get_table()
        if table:
            try:
                response = table.scan()
                return response.get("Items", [])
            except Exception:
                pass
        with self._lock:
            return list(self._in_memory_db.values())

    def create_customer(self, name: str, email: str) -> dict:
        customer_id = str(uuid4())
        created_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        item = {
            "id": customer_id,
            "name": name,
            "email": email,
            "created_at": created_at
        }
        table = self._get_table()
        if table:
            try:
                table.put_item(Item=item)
                return item
            except Exception:
                pass
        with self._lock:
            self._in_memory_db[customer_id] = item
        return item

    def get_customer(self, customer_id: str) -> dict | None:
        table = self._get_table()
        if table:
            try:
                response = table.get_item(Key={"id": customer_id})
                return response.get("Item")
            except Exception:
                pass
        with self._lock:
            return self._in_memory_db.get(customer_id)

    def delete_customer(self, customer_id: str) -> bool:
        table = self._get_table()
        if table:
            try:
                exists = self.get_customer(customer_id) is not None
                if exists:
                    table.delete_item(Key={"id": customer_id})
                    return True
                return False
            except Exception:
                pass
        with self._lock:
            if customer_id in self._in_memory_db:
                del self._in_memory_db[customer_id]
                return True
        return False

customer_store = CustomerStore()

app = FastAPI(
    title=settings.service_name,
    description="Sample FastAPI service deployed through an AWS GitOps pipeline.",
    version=settings.version,
)


def _runtime_environment() -> str:
    return getenv("APP_ENV", "local")


def _missing_required_secrets() -> list[str]:
    runtime_settings = get_settings()
    return [secret_name for secret_name in runtime_settings.required_secrets if not getenv(secret_name)]


def _label_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _request_path_label(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


def _record_request_metric(method: str, path: str, status_code: int, duration_ms: float) -> None:
    metric_key = (method, path, status_code)
    with REQUEST_METRICS_LOCK:
        REQUEST_COUNTS[metric_key] += 1
        REQUEST_DURATION_MS[metric_key] += duration_ms


def _snapshot_request_metrics() -> list[tuple[str, str, int, int, float]]:
    with REQUEST_METRICS_LOCK:
        return [
            (method, path, status_code, count, REQUEST_DURATION_MS[(method, path, status_code)])
            for (method, path, status_code), count in sorted(REQUEST_COUNTS.items())
        ]


def _reset_runtime_metrics() -> None:
    with REQUEST_METRICS_LOCK:
        REQUEST_COUNTS.clear()
        REQUEST_DURATION_MS.clear()
    with CUSTOMER_METRICS_LOCK:
        CUSTOMER_OPERATIONS.clear()
    with customer_store._lock:
        customer_store._in_memory_db.clear()


@app.middleware("http")
async def add_runtime_headers(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid4()))
    started_at = perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        _record_request_metric(
            request.method,
            _request_path_label(request),
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            (perf_counter() - started_at) * 1000,
        )
        raise

    duration_ms = (perf_counter() - started_at) * 1000
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time-ms"] = f"{duration_ms:.2f}"
    response.headers["X-Service-Version"] = get_settings().version
    _record_request_metric(request.method, _request_path_label(request), response.status_code, duration_ms)
    return response


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    """Liveness endpoint used by ALB/ECS health checks."""
    return {"status": "ok"}


@app.get("/ready", tags=["system"])
def ready() -> JSONResponse:
    """Readiness endpoint used by orchestrators during deploys/rollouts."""
    missing_secrets = _missing_required_secrets()

    if missing_secrets:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "degraded",
                "missing_secrets": missing_secrets,
            },
        )

    return JSONResponse(content={"status": "ready"})


@app.get("/version", tags=["system"])
def version() -> dict[str, str]:
    """Returns the application version for traceability across deployments."""
    return {"version": get_settings().version}


@app.get("/info", tags=["system"])
def info() -> dict[str, str]:
    """Returns runtime metadata useful for operations and debugging."""
    runtime_settings = get_settings()
    return {
        "service": runtime_settings.service_name,
        "version": runtime_settings.version,
        "environment": runtime_settings.environment,
        "aws_region": runtime_settings.aws_region,
        "git_sha": runtime_settings.git_sha,
        "hostname": gethostname(),
    }


@app.get("/config", tags=["system"])
def config() -> dict[str, str | int | list[str]]:
    """Returns sanitized runtime configuration without exposing secret values."""
    runtime_settings = get_settings()
    return {
        "service": runtime_settings.service_name,
        "environment": runtime_settings.environment,
        "aws_region": runtime_settings.aws_region,
        "log_level": runtime_settings.log_level,
        "required_secrets": list(runtime_settings.required_secrets),
        "configured_secret_count": runtime_settings.configured_secret_count,
    }


@app.get("/diagnostics", tags=["system"])
def diagnostics() -> dict[str, str | bool | float | list[str]]:
    """Returns deployment diagnostics that help verify runtime state after releases."""
    runtime_settings = get_settings()
    missing_secrets = _missing_required_secrets()
    return {
        "service": runtime_settings.service_name,
        "environment": runtime_settings.environment,
        "version": runtime_settings.version,
        "git_sha": runtime_settings.git_sha,
        "aws_region": runtime_settings.aws_region,
        "hostname": gethostname(),
        "uptime_seconds": round(monotonic() - START_TIME, 3),
        "ready": not missing_secrets,
        "missing_secrets": missing_secrets,
    }


@app.get("/status", tags=["system"])
def status_summary() -> dict[str, str | bool | int | float | list[str]]:
    """Returns a compact operational summary for runbooks and incident checks."""
    runtime_settings = get_settings()
    missing_secrets = _missing_required_secrets()
    request_metrics = _snapshot_request_metrics()

    total_requests = sum(count for _, _, _, count, _ in request_metrics)
    status_2xx_requests = sum(count for _, _, status_code, count, _ in request_metrics if 200 <= status_code < 300)
    status_5xx_requests = sum(count for _, _, status_code, count, _ in request_metrics if status_code >= 500)

    return {
        "service": runtime_settings.service_name,
        "environment": runtime_settings.environment,
        "version": runtime_settings.version,
        "ready": not missing_secrets,
        "missing_secrets": missing_secrets,
        "uptime_seconds": round(monotonic() - START_TIME, 3),
        "requests_total": total_requests,
        "requests_2xx": status_2xx_requests,
        "requests_5xx": status_5xx_requests,
    }


@app.get("/metrics", tags=["system"], response_class=PlainTextResponse)
def metrics() -> PlainTextResponse:
    """Returns a Prometheus-style snapshot of runtime and HTTP request metrics."""
    runtime_settings = get_settings()
    missing_secrets = _missing_required_secrets()
    
    # Calculate current customers count
    current_customers_count = len(customer_store.list_customers())
    
    metric_lines = [
        "# HELP app_info Build and runtime metadata for the service.",
        "# TYPE app_info gauge",
        (
            f'app_info{{service="{_label_value(runtime_settings.service_name)}",'
            f'version="{_label_value(runtime_settings.version)}",'
            f'environment="{_label_value(runtime_settings.environment)}",'
            f'aws_region="{_label_value(runtime_settings.aws_region)}",'
            f'git_sha="{_label_value(runtime_settings.git_sha)}"}} 1'
        ),
        "# HELP app_uptime_seconds Service uptime in seconds.",
        "# TYPE app_uptime_seconds gauge",
        f"app_uptime_seconds {round(monotonic() - START_TIME, 3)}",
        "# HELP app_ready_state Readiness state where 1 means ready and 0 means degraded.",
        "# TYPE app_ready_state gauge",
        f"app_ready_state {0 if missing_secrets else 1}",
        "# HELP app_missing_required_secrets Number of required secrets that are currently missing.",
        "# TYPE app_missing_required_secrets gauge",
        f"app_missing_required_secrets {len(missing_secrets)}",
        "# HELP app_customers_total Total number of registered customers.",
        "# TYPE app_customers_total gauge",
        f"app_customers_total {current_customers_count}",
        "# HELP app_customer_operations_total Total customer operations by action.",
        "# TYPE app_customer_operations_total counter",
    ]

    with CUSTOMER_METRICS_LOCK:
        for action, count in sorted(CUSTOMER_OPERATIONS.items()):
            metric_lines.append(f'app_customer_operations_total{{action="{action}"}} {count}')

    metric_lines.extend([
        "# HELP http_requests_total Total HTTP requests processed by route, method, and status code.",
        "# TYPE http_requests_total counter",
        "# HELP http_request_duration_ms_sum Cumulative request duration in milliseconds by route, method, and status code.",
        "# TYPE http_request_duration_ms_sum counter",
        "# HELP http_request_duration_ms_count Number of request duration samples by route, method, and status code.",
        "# TYPE http_request_duration_ms_count counter",
    ])

    for method, path, status_code, count, duration_ms_sum in _snapshot_request_metrics():
        labels = (
            f'method="{_label_value(method)}",'
            f'path="{_label_value(path)}",'
            f'status_code="{status_code}"'
        )
        metric_lines.append(f"http_requests_total{{{labels}}} {count}")
        metric_lines.append(f"http_request_duration_ms_sum{{{labels}}} {duration_ms_sum:.3f}")
        metric_lines.append(f"http_request_duration_ms_count{{{labels}}} {count}")

    return PlainTextResponse("\n".join(metric_lines) + "\n", media_type="text/plain; version=0.0.4; charset=utf-8")


@app.get("/api/v1/customers", tags=["customers"], response_model=list[Customer])
def list_customers():
    """List all customers."""
    with CUSTOMER_METRICS_LOCK:
        CUSTOMER_OPERATIONS["list"] += 1
    return customer_store.list_customers()


@app.post("/api/v1/customers", tags=["customers"], response_model=Customer, status_code=status.HTTP_201_CREATED)
def create_customer(customer_in: CustomerCreate):
    """Create a new customer."""
    with CUSTOMER_METRICS_LOCK:
        CUSTOMER_OPERATIONS["create"] += 1
    return customer_store.create_customer(customer_in.name, customer_in.email)


@app.get("/api/v1/customers/{customer_id}", tags=["customers"], response_model=Customer)
def get_customer(customer_id: str):
    """Retrieve a single customer by ID."""
    with CUSTOMER_METRICS_LOCK:
        CUSTOMER_OPERATIONS["get"] += 1
    cust = customer_store.get_customer(customer_id)
    if not cust:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"detail": "Customer not found"})
    return cust


@app.delete("/api/v1/customers/{customer_id}", tags=["customers"])
def delete_customer(customer_id: str):
    """Delete a customer by ID."""
    with CUSTOMER_METRICS_LOCK:
        CUSTOMER_OPERATIONS["delete"] += 1
    success = customer_store.delete_customer(customer_id)
    if not success:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"detail": "Customer not found"})
    return {"status": "deleted"}


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    runtime_settings = get_settings()
    return {
        "service": runtime_settings.service_name,
        "docs": "/docs",
        "health": "/health",
        "ready": "/ready",
        "version": "/version",
        "info": "/info",
        "config": "/config",
        "diagnostics": "/diagnostics",
        "status": "/status",
        "metrics": "/metrics",
        "customers": "/api/v1/customers",
    }
