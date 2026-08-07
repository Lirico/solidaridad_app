"""FastAPI dependency wiring."""

from typing import Annotated

from fastapi import Depends

from application.payments.authorize_payment import AuthorizePayment
from application.payments.ports import IsoProcessor
from application.payments.void_payment import VoidPayment
from config.settings import Settings, get_settings
from infrastructure.iso.mock_processor import MockIsoProcessor
from infrastructure.iso.tcp_processor import TcpIsoProcessor


def get_iso_processor(
    settings: Annotated[Settings, Depends(get_settings)],
) -> IsoProcessor:
    transport = settings.iso_transport.lower().strip()
    if transport == "tcp":
        return TcpIsoProcessor(settings)
    return MockIsoProcessor()


def get_authorize_payment(
    processor: Annotated[IsoProcessor, Depends(get_iso_processor)],
) -> AuthorizePayment:
    return AuthorizePayment(processor)


def get_void_payment(
    processor: Annotated[IsoProcessor, Depends(get_iso_processor)],
) -> VoidPayment:
    return VoidPayment(processor)
