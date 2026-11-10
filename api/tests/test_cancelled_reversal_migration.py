import importlib
from unittest.mock import MagicMock, call


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261110_0017_cancelled_reversal"
    )


def test_upgrade_adds_cancelled_state_and_reason_constraint(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    operations.drop_constraint.assert_called_once_with(
        "ck_processor_jobs_state", "processor_jobs", type_="check"
    )
    assert operations.create_check_constraint.call_args_list == [
        call(
            "ck_processor_jobs_state",
            "processor_jobs",
            "state IN ('READY', 'PROCESSING', 'RETRY', 'COMPLETED', "
            "'CANCELLED', 'MANUAL_REVIEW')",
        ),
        call(
            "ck_processor_jobs_cancelled_reason",
            "processor_jobs",
            "state <> 'CANCELLED' OR "
            "(result IS NOT NULL AND completed_at IS NOT NULL)",
        ),
    ]


def test_downgrade_preserves_cancelled_rows_as_completed(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    operations.execute.assert_called_once_with(
        "UPDATE processor_jobs SET state = 'COMPLETED' WHERE state = 'CANCELLED'"
    )
    assert operations.drop_constraint.call_args_list == [
        call(
            "ck_processor_jobs_cancelled_reason",
            "processor_jobs",
            type_="check",
        ),
        call("ck_processor_jobs_state", "processor_jobs", type_="check"),
    ]
