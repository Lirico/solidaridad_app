from functools import lru_cache
from typing import Self
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import PrivateAttr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_ALLOWED_TRANSPORTS = frozenset({"mock", "tcp"})


class TransportNotConfiguredError(RuntimeError):
    """ISO_TRANSPORT quedó en el default del código."""


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    iso_timezone: str = "America/Argentina/Buenos_Aires"
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
    _explicit_fields: set[str] = PrivateAttr(default_factory=set)

    @field_validator("iso_timezone")
    @classmethod
    def validate_iso_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("iso_timezone debe ser una zona IANA válida") from exc
        return value

    @model_validator(mode="after")
    def validate_iso_transport(self) -> Self:
        explicit = set(self.model_fields_set)
        transport = self.iso_transport.strip().lower()
        env = self.app_env.strip().lower()
        if transport not in _ALLOWED_TRANSPORTS:
            raise ValueError("ISO_TRANSPORT debe ser mock o tcp")
        if transport == "mock" and env != "local":
            raise ValueError("ISO_TRANSPORT=mock solo se permite con APP_ENV=local")
        self._explicit_fields = explicit
        self.iso_transport = transport
        self.app_env = env
        return self


def ensure_explicit_transport(settings: Settings) -> Settings:
    if "iso_transport" not in settings._explicit_fields:
        raise TransportNotConfiguredError(
            "ISO_TRANSPORT no está definido. "
            "El gateway no arranca con el mock implícito."
        )
    return settings


@lru_cache
def get_settings() -> Settings:
    return ensure_explicit_transport(Settings())
