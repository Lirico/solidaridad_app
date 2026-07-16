from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    iso_transport: str = "mock"
    iso_host: str = "127.0.0.1"
    iso_port: int = 4452
    iso_connect_timeout_seconds: float = 5.0
    iso_read_timeout_seconds: float = 30.0
    iso_tpdu: str = "6000030000"
    iso_nii: str = "003"
    iso_processing_code: str = "000000"
    iso_pos_entry_mode: str = "012"
    iso_pos_condition_code: str = "00"


@lru_cache
def get_settings() -> Settings:
    return Settings()
