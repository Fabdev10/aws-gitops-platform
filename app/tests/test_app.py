from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health_endpoint() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_endpoint() -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_version_endpoint() -> None:
    response = client.get("/version")
    assert response.status_code == 200
    assert "version" in response.json()


def test_info_endpoint() -> None:
    response = client.get("/info")
    assert response.status_code == 200
    payload = response.json()
    assert payload["service"] == "aws-gitops-platform"
    assert payload["environment"] in ["local", "staging", "production"] or isinstance(payload["environment"], str)


def test_root_endpoint_exposes_links() -> None:
    response = client.get("/")
    assert response.status_code == 200
    payload = response.json()
    assert payload["docs"] == "/docs"
    assert payload["health"] == "/health"
    assert payload["ready"] == "/ready"
    assert payload["version"] == "/version"
    assert payload["info"] == "/info"
