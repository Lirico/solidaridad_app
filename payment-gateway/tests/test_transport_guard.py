import pytest
from pydantic import ValidationError

from config.settings import (
    Settings,
    TransportNotConfiguredError,
    ensure_explicit_transport,
    get_settings,
)
from presentation.dependencies import get_iso_processor


def _without_env_file(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ISO_TRANSPORT", raising=False)
    monkeypatch.delenv("APP_ENV", raising=False)
    original = Settings

    def factory(**kwargs: object) -> Settings:
        kwargs["_env_file"] = None
        return original(**kwargs)  # type: ignore[arg-type]

    monkeypatch.setattr("config.settings.Settings", factory)
    get_settings.cache_clear()


def test_missing_transport_refuses_startup(monkeypatch: pytest.MonkeyPatch) -> None:
    _without_env_file(monkeypatch)

    with pytest.raises(TransportNotConfiguredError):
        get_settings()


def test_default_settings_object_stays_available_for_iso_builders(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("ISO_TRANSPORT", raising=False)
    monkeypatch.delenv("APP_ENV", raising=False)

    settings = Settings(_env_file=None)

    assert settings.iso_transport == "mock"
    with pytest.raises(TransportNotConfiguredError):
        ensure_explicit_transport(settings)


def test_unknown_transport_is_rejected() -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, iso_transport="live")


def test_blank_transport_is_rejected() -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, iso_transport="  ")


def test_tcp_is_case_insensitive() -> None:
    settings = Settings(_env_file=None, iso_transport=" TCP ", app_env="prod")

    assert settings.iso_transport == "tcp"
    assert settings.app_env == "prod"
    assert ensure_explicit_transport(settings) is settings


def test_mock_is_local_only() -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, iso_transport="mock", app_env="prod")

    local = Settings(_env_file=None, iso_transport=" mock ", app_env=" local ")
    assert local.iso_transport == "mock"
    assert local.app_env == "local"


def test_get_settings_reads_explicit_transport(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _without_env_file(monkeypatch)
    monkeypatch.setenv("ISO_TRANSPORT", "tcp")
    monkeypatch.setenv("APP_ENV", "prod")

    settings = get_settings()

    assert settings.iso_transport == "tcp"
    assert settings.app_env == "prod"
    get_settings.cache_clear()


def test_unknown_transport_does_not_select_mock() -> None:
    settings = Settings.model_construct(iso_transport="live")

    with pytest.raises(RuntimeError, match="ISO_TRANSPORT inválido"):
        get_iso_processor(settings)
