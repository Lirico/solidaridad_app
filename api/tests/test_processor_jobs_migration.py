import importlib
from unittest.mock import MagicMock

from sqlalchemy import CheckConstraint, ForeignKeyConstraint, UniqueConstraint


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261013_0009_processor_jobs_and_config"
    )


def test_migration_creates_jobs_constraints_and_default_config(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    jobs_call = operations.create_table.call_args_list[0]
    assert jobs_call.args[0] == "processor_jobs"
    jobs_items = jobs_call.args[1:]
    constraint_names = {
        item.name
        for item in jobs_items
        if isinstance(item, (CheckConstraint, UniqueConstraint))
    }
    assert {
        "uq_processor_jobs_transaction_operation",
        "uq_processor_jobs_transaction_reversal_stan",
        "ck_processor_jobs_operation_type",
        "ck_processor_jobs_state",
        "ck_processor_jobs_attempt_count",
        "ck_processor_jobs_processing_claim",
        "ck_processor_jobs_completed_result",
    } == constraint_names
    foreign_keys = [
        item for item in jobs_items if isinstance(item, ForeignKeyConstraint)
    ]
    assert len(foreign_keys) == 1
    assert list(foreign_keys[0].column_keys) == ["transaction_id"]

    config_call = operations.create_table.call_args_list[1]
    assert config_call.args[0] == "payment_processing_config"
    config_checks = {
        item.name for item in config_call.args[1:] if isinstance(item, CheckConstraint)
    }
    assert len(config_checks) == 11

    inserted = operations.bulk_insert.call_args.args[1]
    assert inserted == [
        {
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
    ]


def test_migration_downgrade_removes_config_then_jobs(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    assert [call.args[0] for call in operations.drop_table.call_args_list] == [
        "payment_processing_config",
        "processor_jobs",
    ]
    operations.drop_index.assert_called_once_with(
        "ix_processor_jobs_available",
        table_name="processor_jobs",
    )
