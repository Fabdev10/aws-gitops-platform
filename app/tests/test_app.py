import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.settings import get_settings


client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_health_endpoint() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_endpoint() -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_ready_endpoint_reports_missing_required_secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("REQUIRED_SECRETS", "API_KEY,DB_PASSWORD")
    monkeypatch.setenv("API_KEY", "configured")

    response = client.get("/ready")

    assert response.status_code == 503
    assert response.json() == {
        "status": "degraded",
        "missing_secrets": ["DB_PASSWORD"],
    }


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
    assert "aws_region" in payload
    assert "git_sha" in payload
    assert "hostname" in payload


def test_config_endpoint_returns_sanitized_runtime_configuration(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "staging")
    monkeypatch.setenv("AWS_REGION", "eu-west-1")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("REQUIRED_SECRETS", "API_KEY")
    monkeypatch.setenv("API_KEY", "super-secret-value")

    response = client.get("/config")

    assert response.status_code == 200
    payload = response.json()
    assert payload == {
        "service": "aws-gitops-platform",
        "environment": "staging",
        "aws_region": "eu-west-1",
        "log_level": "DEBUG",
        "required_secrets": ["API_KEY"],
        "configured_secret_count": 1,
    }
    assert "super-secret-value" not in response.text


def test_diagnostics_endpoint_exposes_runtime_state(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    monkeypatch.setenv("REQUIRED_SECRETS", "API_KEY")

    response = client.get("/diagnostics")

    assert response.status_code == 200
    payload = response.json()
    assert payload["version"] == "1.2.3"
    assert payload["git_sha"] == "abc1234"
    assert payload["ready"] is False
    assert payload["missing_secrets"] == ["API_KEY"]
    assert payload["uptime_seconds"] >= 0


def test_runtime_headers_are_added_to_responses() -> None:
    response = client.get("/health", headers={"x-request-id": "req-123"})

    assert response.status_code == 200
    assert response.headers["x-request-id"] == "req-123"
    assert float(response.headers["x-response-time-ms"]) >= 0
    assert response.headers["x-service-version"]


def test_root_endpoint_exposes_links() -> None:
    response = client.get("/")
    assert response.status_code == 200
    payload = response.json()
    assert payload["docs"] == "/docs"
    assert payload["health"] == "/health"
    assert payload["ready"] == "/ready"
    assert payload["version"] == "/version"
    assert payload["info"] == "/info"
    assert payload["config"] == "/config"
    assert payload["diagnostics"] == "/diagnostics"
