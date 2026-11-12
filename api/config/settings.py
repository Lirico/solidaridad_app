from functools import lru_cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

LAB_JWT_SECRET = "change-me-local-dev-only-use-a-long-random-string"
LAB_DATABASE_CREDENTIALS = "solidaridad:solidaridad"


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
    jwt_expire_minutes: int = 1440
    postgres_user: str = "solidaridad"
    postgres_password: str = "solidaridad"
    postgres_db: str = "solidaridad"
    postgres_port: int = 5434
    payment_gateway_url: str = "http://127.0.0.1:8001"
    payment_gateway_timeout_seconds: float = 35.0
    embedded_recovery_worker_enabled: bool = True
    embedded_recovery_worker_shutdown_grace_seconds: float = 40.0
    recovery_worker_max_iteration_age_seconds: float = Field(default=30.0, gt=0)

    @field_validator("business_timezone")
    @classmethod
    def validate_business_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("business_timezone debe ser una zona IANA válida") from exc
        return value


def ensure_explicit_lab_secrets(settings: Settings) -> Settings:
    env = settings.app_env.strip().lower()
    if "app_env" not in settings.model_fields_set:
        raise LabSecretsError(
            "APP_ENV no está definido. La API no arranca como local implícito."
        )
    if env != "local":
        if settings.jwt_secret == LAB_JWT_SECRET:
            raise LabSecretsError(
                "JWT_SECRET de laboratorio no vale fuera de APP_ENV=local."
            )
        if LAB_DATABASE_CREDENTIALS in settings.database_url:
            raise LabSecretsError(
                "La clave de base de laboratorio no vale fuera de APP_ENV=local."
            )
    settings.app_env = env
    return settings


@lru_cache
def get_settings() -> Settings:
    return ensure_explicit_lab_secrets(Settings())
