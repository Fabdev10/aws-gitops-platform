from os import getenv

from fastapi import FastAPI

app = FastAPI(
    title="aws-gitops-platform",
    description="Sample FastAPI service deployed through an AWS GitOps pipeline.",
    version=getenv("APP_VERSION", "0.1.0"),
)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    """Liveness endpoint used by ALB/ECS health checks."""
    return {"status": "ok"}


@app.get("/version", tags=["system"])
def version() -> dict[str, str]:
    """Returns the application version for traceability across deployments."""
    return {"version": app.version}


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {"service": app.title, "docs": "/docs"}
