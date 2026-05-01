from os import getenv
from socket import gethostname
from time import monotonic, perf_counter
from uuid import uuid4

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.settings import get_settings

START_TIME = monotonic()
settings = get_settings()

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


@app.middleware("http")
async def add_runtime_headers(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid4()))
    started_at = perf_counter()
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time-ms"] = f"{(perf_counter() - started_at) * 1000:.2f}"
    response.headers["X-Service-Version"] = get_settings().version
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
    }
