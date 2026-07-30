from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
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
    luhn_check_enabled: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
