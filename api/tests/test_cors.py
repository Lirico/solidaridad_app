import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from config import Settings, docs_enabled
from main import create_app
from presentation import create_router


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {"embedded_recovery_worker_enabled": False}
    values.update(overrides)
    return Settings(**values)


def _client(settings: Settings) -> TestClient:
    return TestClient(create_app(create_router(), settings=settings))


def test_default_cors_does_not_echo_an_arbitrary_origin() -> None:
    with _client(_settings()) as client:
        response = client.options(
            "/health/live",
            headers={
                "Origin": "https://evil.example",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert "access-control-allow-origin" not in response.headers
    assert "access-control-allow-credentials" not in response.headers


def test_listed_origin_receives_credentials_and_another_does_not() -> None:
    settings = _settings(cors_origins="https://caja.example")
    with _client(settings) as client:
        allowed = client.options(
            "/health/live",
            headers={
                "Origin": "https://caja.example",
                "Access-Control-Request-Method": "GET",
            },
        )
        denied = client.options(
            "/health/live",
            headers={
                "Origin": "https://evil.example",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert allowed.status_code == 200
    assert allowed.headers["access-control-allow-origin"] == "https://caja.example"
    assert allowed.headers["access-control-allow-credentials"] == "true"
    assert "access-control-allow-origin" not in denied.headers


def test_blank_cors_setting_allows_no_origins() -> None:
    assert _settings(cors_origins="  ").cors_origins == ()


def test_blank_origin_in_the_list_is_rejected() -> None:
    with pytest.raises(ValidationError, match="origen vacío"):
        _settings(cors_origins="https://caja.example,")


def test_wildcard_origin_is_rejected() -> None:
    with pytest.raises(ValidationError, match=r"CORS_ORIGINS no acepta \*"):
        _settings(cors_origins="*")


def test_origin_with_path_is_rejected() -> None:
    with pytest.raises(ValidationError, match="sin path"):
        _settings(cors_origins="https://caja.example/app")


def test_docs_stay_in_the_lab_and_disappear_in_production() -> None:
    assert docs_enabled(_settings(app_env="local")) is True
    assert docs_enabled(_settings(app_env="dev")) is True
    assert docs_enabled(_settings(app_env="test")) is True
    assert docs_enabled(_settings(app_env="staging")) is False
    assert docs_enabled(_settings(app_env="prod")) is False
    assert docs_enabled(_settings(app_env="production")) is False

    with _client(_settings(app_env="local")) as local:
        assert local.get("/docs").status_code == 200
        assert local.get("/openapi.json").status_code == 200

    with _client(_settings(app_env="production")) as production:
        assert production.get("/docs").status_code == 404
        assert production.get("/redoc").status_code == 404
        assert production.get("/openapi.json").status_code == 404
