from os import getenv

from fastapi import FastAPI

app = FastAPI(
    title="aws-gitops-platform",
    description="Sample FastAPI service deployed through an AWS GitOps pipeline.",
    version=getenv("APP_VERSION", "0.1.0"),
)


def _runtime_environment() -> str:
    return getenv("APP_ENV", "local")


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    """Liveness endpoint used by ALB/ECS health checks."""
    return {"status": "ok"}


@app.get("/ready", tags=["system"])
def ready() -> dict[str, str]:
    """Readiness endpoint used by orchestrators during deploys/rollouts."""
    return {"status": "ready"}


@app.get("/version", tags=["system"])
def version() -> dict[str, str]:
    """Returns the application version for traceability across deployments."""
    return {"version": app.version}


@app.get("/info", tags=["system"])
def info() -> dict[str, str]:
    """Returns runtime metadata useful for operations and debugging."""
    return {
        "service": app.title,
        "version": app.version,
        "environment": _runtime_environment(),
    }


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {
        "service": app.title,
        "docs": "/docs",
        "health": "/health",
        "ready": "/ready",
        "version": "/version",
        "info": "/info",
    }
