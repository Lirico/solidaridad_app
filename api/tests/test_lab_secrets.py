import base64
from collections.abc import Generator

import pytest

from config.settings import (
    LAB_DATABASE_CREDENTIALS,
    LAB_JWT_SECRET,
    LAB_PAN_ENCRYPTION_KEY,
    MIN_NON_LOCAL_JWT_SECRET_LENGTH,
    LabSecretsError,
    Settings,
    ensure_explicit_lab_secrets,
    get_settings,
)

_REAL_JWT = "prod-jwt-secret-not-the-lab-value"
_REAL_PAN_KEY = base64.b64encode(b"p" * 32).decode()
_REAL_DATABASE_URL = "postgresql+psycopg://app:real-secret@db.internal:5432/solidaridad"
_LAB_DATABASE_URL = (
    f"postgresql+psycopg://{LAB_DATABASE_CREDENTIALS}@localhost:5434/solidaridad"
)


def _without_env_file(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("APP_ENV", "JWT_SECRET", "DATABASE_URL", "PAN_ENCRYPTION_KEY"):
        monkeypatch.delenv(name, raising=False)
    original = Settings

    def factory(**kwargs: object) -> Settings:
        kwargs["_env_file"] = None
        return original(**kwargs)  # type: ignore[arg-type]

    monkeypatch.setattr("config.settings.Settings", factory)
    get_settings.cache_clear()


@pytest.fixture
def isolated_settings(monkeypatch: pytest.MonkeyPatch) -> Generator[None]:
    _without_env_file(monkeypatch)
    yield
    get_settings.cache_clear()


def test_missing_app_env_refuses_startup(isolated_settings: None) -> None:
    del isolated_settings
    with pytest.raises(LabSecretsError, match="no está definido"):
        get_settings()


def test_lab_jwt_refused_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", LAB_JWT_SECRET)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)

    with pytest.raises(LabSecretsError, match="JWT_SECRET"):
        get_settings()


def test_lab_database_refused_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _LAB_DATABASE_URL)

    with pytest.raises(LabSecretsError, match="clave de base"):
        get_settings()


def test_production_with_own_secrets_starts(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", _REAL_PAN_KEY)

    settings = get_settings()

    assert settings.app_env == "production"
    assert settings.jwt_secret == _REAL_JWT
    assert settings.database_url == _REAL_DATABASE_URL
    assert settings.pan_encryption_key == _REAL_PAN_KEY


def test_explicit_local_keeps_lab_secrets(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", " local ")

    settings = get_settings()

    assert settings.app_env == "local"
    assert settings.jwt_secret == LAB_JWT_SECRET
    assert settings.pan_encryption_key == LAB_PAN_ENCRYPTION_KEY
    assert LAB_DATABASE_CREDENTIALS in settings.database_url


def test_settings_object_keeps_lab_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("APP_ENV", "JWT_SECRET", "DATABASE_URL", "PAN_ENCRYPTION_KEY"):
        monkeypatch.delenv(name, raising=False)

    settings = Settings(_env_file=None)

    assert settings.app_env == "local"
    assert settings.jwt_secret == LAB_JWT_SECRET
    assert settings.pan_encryption_key == LAB_PAN_ENCRYPTION_KEY
    assert LAB_DATABASE_CREDENTIALS in settings.database_url
    assert settings.business_timezone == "America/Argentina/Buenos_Aires"
    with pytest.raises(LabSecretsError, match="no está definido"):
        ensure_explicit_lab_secrets(settings)


def test_blank_app_env_refuses_startup(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "   ")

    with pytest.raises(LabSecretsError, match="está vacío"):
        get_settings()


def test_unknown_app_env_refuses_startup(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "qa")

    with pytest.raises(LabSecretsError, match="no es un ambiente conocido"):
        get_settings()


def test_short_jwt_refused_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "x" * (MIN_NON_LOCAL_JWT_SECRET_LENGTH - 1))
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)

    with pytest.raises(LabSecretsError, match="demasiado corto"):
        get_settings()


def test_minimum_length_jwt_starts_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    secret = "y" * MIN_NON_LOCAL_JWT_SECRET_LENGTH
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", secret)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", _REAL_PAN_KEY)

    settings = get_settings()

    assert settings.jwt_secret == secret


def test_similar_database_credentials_are_not_lab_secrets(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    database_url = (
        "postgresql+psycopg://solidaridad:solidaridad-extra@localhost:5434/solidaridad"
    )
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", _REAL_PAN_KEY)

    settings = get_settings()

    assert settings.database_url == database_url


def test_lab_credentials_outside_userinfo_do_not_block_startup(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    database_url = (
        "postgresql+psycopg://app:real-secret@db.internal:5432/solidaridad"
        "?application_name=solidaridad:solidaridad"
    )
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", _REAL_PAN_KEY)

    settings = get_settings()

    assert settings.database_url == database_url


def test_unparseable_database_url_refuses_startup(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", "not a url")

    with pytest.raises(LabSecretsError, match="no se puede interpretar"):
        get_settings()


def test_missing_pan_key_refused_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)

    with pytest.raises(LabSecretsError, match="PAN_ENCRYPTION_KEY ausente"):
        get_settings()


def test_lab_pan_key_refused_outside_local(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", LAB_PAN_ENCRYPTION_KEY)

    with pytest.raises(LabSecretsError, match="de laboratorio"):
        get_settings()


def test_pan_key_must_decode_to_32_bytes(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", base64.b64encode(b"short").decode())

    with pytest.raises(LabSecretsError, match="32 bytes"):
        get_settings()


def test_pan_key_must_be_base64(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", _REAL_JWT)
    monkeypatch.setenv("DATABASE_URL", _REAL_DATABASE_URL)
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", "not base64 !!!")

    with pytest.raises(LabSecretsError, match="base64"):
        get_settings()


def test_local_rejects_a_pan_key_that_is_not_32_bytes(
    isolated_settings: None,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    del isolated_settings
    monkeypatch.setenv("APP_ENV", "local")
    monkeypatch.setenv("PAN_ENCRYPTION_KEY", base64.b64encode(b"short").decode())

    with pytest.raises(LabSecretsError, match="32 bytes"):
        get_settings()
