from datetime import UTC, datetime
from unittest.mock import MagicMock

from sqlalchemy.dialects import postgresql

from persistence.repositories.recovery_alert_repository import RecoveryAlertRepository


def test_opens_one_durable_alert_per_job_and_cause() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = 9

    opened = RecoveryAlertRepository(session).open_for_job(
        processor_job_id=7,
        cause="PROCESSING_TIMEOUT",
        opened_at=datetime(2026, 10, 14, 12, tzinfo=UTC),
    )

    assert opened is True
    statement = session.execute.call_args.args[0]
    compiled = str(statement.compile(dialect=postgresql.dialect()))
    assert (
        "ON CONFLICT ON CONSTRAINT uq_recovery_alerts_job_cause DO NOTHING"
        in compiled
    )


def test_reports_duplicate_alert_without_creating_another_record() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = None

    opened = RecoveryAlertRepository(session).open_for_job(
        processor_job_id=7,
        cause="PROCESSING_TIMEOUT",
        opened_at=datetime(2026, 10, 14, 12, tzinfo=UTC),
    )

    assert opened is False
