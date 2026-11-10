from functools import lru_cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    business_timezone: str = "America/Argentina/Buenos_Aires"
    database_url: str = (
        "postgresql+psycopg://solidaridad:solidaridad@localhost:5434/solidaridad"
    )
    jwt_secret: str = "change-me-local-dev-only-use-a-long-random-string"
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


@lru_cache
def get_settings() -> Settings:
    return Settings()
