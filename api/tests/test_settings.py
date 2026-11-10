import pytest
from pydantic import ValidationError

from config import Settings


def test_business_timezone_defaults_to_argentina() -> None:
    assert Settings().business_timezone == "America/Argentina/Buenos_Aires"


def test_recovery_worker_is_enabled_by_default() -> None:
    assert Settings().embedded_recovery_worker_enabled is True


def test_business_timezone_rejects_unknown_zone() -> None:
    with pytest.raises(ValidationError, match="zona IANA válida"):
        Settings(business_timezone="America/No_Existe")
