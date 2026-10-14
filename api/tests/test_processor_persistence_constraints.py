from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, insert
from sqlalchemy.exc import IntegrityError

from persistence.models.payment_processing_config import PaymentProcessingConfig
from persistence.models.processor_job import ProcessorJob


def _config_values() -> dict[str, object]:
    return {
        "id": 1,
        "config_name": "default",
        "max_authorization_attempts": 3,
        "authorization_initial_delay_ms": 100,
        "authorization_max_delay_ms": 500,
        "authorization_backoff_multiplier": 2,
        "max_reversal_attempts": 5,
        "reversal_initial_delay_seconds": 5,
        "reversal_max_delay_seconds": 300,
        "reversal_backoff_multiplier": 2,
        "jitter_percentage": 20,
        "processing_timeout_seconds": 60,
        "worker_poll_interval_seconds": 1,
    }


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("max_authorization_attempts", 0),
        ("authorization_initial_delay_ms", -1),
        ("authorization_max_delay_ms", 99),
        ("authorization_backoff_multiplier", 0.5),
        ("max_reversal_attempts", 0),
        ("reversal_initial_delay_seconds", -1),
        ("reversal_max_delay_seconds", 4),
        ("reversal_backoff_multiplier", 0.5),
        ("jitter_percentage", 101),
        ("processing_timeout_seconds", 0),
        ("worker_poll_interval_seconds", 0),
    ],
)
def test_database_rejects_invalid_payment_config(field: str, value: object) -> None:
    engine = create_engine("sqlite://")
    PaymentProcessingConfig.__table__.create(engine)
    values = _config_values()
    values[field] = value

    with engine.connect() as connection, pytest.raises(IntegrityError):
        connection.execute(insert(PaymentProcessingConfig).values(**values))


def _job_values(
    *,
    job_id: int = 1,
    operation_type: str = "REVERSE",
) -> dict[str, object]:
    now = datetime.now(UTC)
    return {
        "id": job_id,
        "transaction_id": 10,
        "operation_type": operation_type,
        "state": "READY",
        "attempt_count": 0,
        "next_attempt_at": now,
        "original_stan": "000123",
        "original_ticket": "00000042",
        "reversal_stan": "900123",
        "created_at": now,
        "updated_at": now,
    }


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("operation_type", "VOID"),
        ("state", "UNKNOWN"),
        ("attempt_count", -1),
        ("state", "PROCESSING"),
        ("state", "COMPLETED"),
    ],
)
def test_database_rejects_invalid_processor_job(field: str, value: object) -> None:
    engine = create_engine("sqlite://")
    ProcessorJob.__table__.create(engine)
    values = _job_values()
    values[field] = value

    with engine.connect() as connection, pytest.raises(IntegrityError):
        connection.execute(insert(ProcessorJob).values(**values))


@pytest.mark.parametrize("duplicate_field", ["operation_type", "reversal_stan"])
def test_database_rejects_duplicate_job_identity(duplicate_field: str) -> None:
    engine = create_engine("sqlite://")
    ProcessorJob.__table__.create(engine)
    first = _job_values()
    second = _job_values(job_id=2, operation_type="AUTHORIZE")
    if duplicate_field == "operation_type":
        second["operation_type"] = first["operation_type"]
        second["reversal_stan"] = "900124"

    with engine.begin() as connection:
        connection.execute(insert(ProcessorJob).values(**first))
        with pytest.raises(IntegrityError):
            connection.execute(insert(ProcessorJob).values(**second))
