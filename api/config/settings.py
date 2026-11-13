from functools import lru_cache
from typing import Annotated
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict
from sqlalchemy.engine.url import make_url
from sqlalchemy.exc import ArgumentError

LAB_JWT_SECRET = "change-me-local-dev-only-use-a-long-random-string"
LAB_DATABASE_USER = "solidaridad"
LAB_DATABASE_PASSWORD = "solidaridad"
LAB_DATABASE_CREDENTIALS = f"{LAB_DATABASE_USER}:{LAB_DATABASE_PASSWORD}"
MIN_NON_LOCAL_JWT_SECRET_LENGTH = 32
KNOWN_APP_ENVS = frozenset({"dev", "local", "prod", "production", "staging", "test"})


class LabSecretsError(RuntimeError):
    """La API no arranca con secretos de laboratorio implícitos."""


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    business_timezone: str = "America/Argentina/Buenos_Aires"
    database_url: str = (
        f"postgresql+psycopg://{LAB_DATABASE_CREDENTIALS}@localhost:5434/solidaridad"
    )
    jwt_secret: str = LAB_JWT_SECRET
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 90
    # Espejo del Compose local. El proceso conecta con database_url.
    # postgres_password no se lee en runtime: Compose exige POSTGRES_PASSWORD.
    postgres_user: str = "solidaridad"
    postgres_password: str = "solidaridad"
    postgres_db: str = "solidaridad"
    postgres_port: int = 5434
    payment_gateway_url: str = "http://127.0.0.1:8001"
    payment_gateway_timeout_seconds: float = 35.0
    embedded_recovery_worker_enabled: bool = True
    embedded_recovery_worker_shutdown_grace_seconds: float = 40.0
    recovery_worker_max_iteration_age_seconds: float = Field(default=30.0, gt=0)
    cors_origins: Annotated[tuple[str, ...], NoDecode] = ()

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: object) -> tuple[str, ...]:
        if value is None:
            return ()
        if isinstance(value, str):
            if not value.strip():
                return ()
            raw_parts: list[object] = list(value.split(","))
        elif isinstance(value, (list, tuple)):
            raw_parts = list(value)
        else:
            raise ValueError(
                "CORS_ORIGINS debe ser una lista de orígenes separada por comas."
            )
        origins: list[str] = []
        for part in raw_parts:
            origin = str(part).strip()
            if not origin:
                raise ValueError("CORS_ORIGINS no acepta un origen vacío.")
            _reject_invalid_origin(origin)
            origins.append(origin)
        return tuple(origins)

    @field_validator("business_timezone")
    @classmethod
    def validate_business_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("business_timezone debe ser una zona IANA válida") from exc
        return value

    @field_validator("app_env")
    @classmethod
    def normalize_app_env(cls, value: str) -> str:
        return value.strip().lower()


def _reject_invalid_origin(origin: str) -> None:
    if origin == "*":
        raise ValueError("CORS_ORIGINS no acepta *.")
    parts = urlsplit(origin)
    if (
        parts.scheme not in {"http", "https"}
        or parts.hostname is None
        or parts.username is not None
        or parts.password is not None
        or parts.path not in {"",}
        or parts.query
        or parts.fragment
    ):
        raise ValueError("CORS_ORIGINS solo acepta orígenes http o https sin path.")


def ensure_explicit_lab_secrets(settings: Settings) -> Settings:
    if "app_env" not in settings.model_fields_set:
        raise LabSecretsError(
            "APP_ENV no está definido. La API no arranca como local implícito."
        )
    if not settings.app_env:
        raise LabSecretsError("APP_ENV está vacío.")
    if settings.app_env not in KNOWN_APP_ENVS:
        known = ", ".join(sorted(KNOWN_APP_ENVS))
        raise LabSecretsError(
            f"APP_ENV={settings.app_env!r} no es un ambiente conocido ({known})."
        )
    if settings.app_env != "local":
        _reject_non_local_lab_secrets(settings)
    return settings


def _reject_non_local_lab_secrets(settings: Settings) -> None:
    secret_is_lab = settings.jwt_secret == LAB_JWT_SECRET
    secret_is_short = len(settings.jwt_secret) < MIN_NON_LOCAL_JWT_SECRET_LENGTH
    if secret_is_lab or secret_is_short:
        raise LabSecretsError(
            "JWT_SECRET de laboratorio o demasiado corto "
            "no vale fuera de APP_ENV=local."
        )
    username, password = database_credentials(settings.database_url)
    if (username, password) == (LAB_DATABASE_USER, LAB_DATABASE_PASSWORD):
        raise LabSecretsError(
            "La clave de base de laboratorio no vale fuera de APP_ENV=local."
        )


def database_credentials(database_url: str) -> tuple[str, str]:
    try:
        url = make_url(database_url)
    except ArgumentError as exc:
        raise LabSecretsError("DATABASE_URL no se puede interpretar.") from exc
    return url.username or "", url.password or ""


@lru_cache
def get_settings() -> Settings:
    return ensure_explicit_lab_secrets(Settings())
