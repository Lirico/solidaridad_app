"""Construct one isolated database iteration for the embedded worker."""

import os
import socket
from collections.abc import Callable
from decimal import Decimal
from uuid import uuid4

from sqlalchemy.orm import Session

from application.payments.reversal_job_worker import ReversalJobWorker
from application.payments.stale_processing_job_monitor import StaleProcessingJobMonitor
from config.settings import Settings
from infrastructure.payments.http_gateway import HttpPaymentGateway
from persistence.database import SessionLocal
from persistence.repositories.payment_processing_config_repository import (
    PaymentProcessingConfigRepository,
)
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository
from persistence.repositories.transaction_repository import TransactionRepository


def default_worker_id() -> str:
    """Identify one loop instance without relying on deployment-specific names."""
    return f"{socket.gethostname()}:{os.getpid()}:{uuid4()}"


def create_embedded_recovery_iteration(
    *,
    settings: Settings,
    worker_id: str | None = None,
    session_factory: Callable[[], Session] = SessionLocal,
    gateway_factory: Callable[[], HttpPaymentGateway] | None = None,
) -> Callable[[Callable[[], bool]], float]:
    """Return a callback that opens and closes a DB session for every loop."""
    resolved_worker_id = worker_id or default_worker_id()
    resolved_gateway_factory = gateway_factory or (lambda: HttpPaymentGateway(
        base_url=settings.payment_gateway_url,
        timeout_seconds=settings.payment_gateway_timeout_seconds,
    ))

    def run_iteration(should_stop: Callable[[], bool]) -> float:
        session = session_factory()
        gateway = resolved_gateway_factory()
        try:
            configs = PaymentProcessingConfigRepository(session)
            if not should_stop():
                ReversalJobWorker(
                    worker_id=resolved_worker_id,
                    session=session,
                    transactions=TransactionRepository(session),
                    jobs=ProcessorJobRepository(session),
                    alerts=RecoveryAlertRepository(session),
                    configs=configs,
                    gateway=gateway,
                    should_stop=should_stop,
                ).run_once()
            if not should_stop():
                StaleProcessingJobMonitor(
                    session=session,
                    jobs=ProcessorJobRepository(session),
                    alerts=RecoveryAlertRepository(session),
                    configs=configs,
                ).run_once()
            poll_interval = configs.get_default().worker_poll_interval_seconds
            return _positive_seconds(poll_interval)
        finally:
            session.rollback()
            session.close()
            gateway.close()

    return run_iteration


def _positive_seconds(value: Decimal) -> float:
    seconds = float(value)
    if seconds <= 0:
        raise ValueError("worker poll interval must be positive")
    return seconds
