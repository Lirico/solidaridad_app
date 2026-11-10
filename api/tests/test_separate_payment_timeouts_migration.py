import importlib
from unittest.mock import MagicMock, call

from sqlalchemy import Column


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261110_0018_separate_payment_timeouts"
    )


def test_upgrade_renames_budget_and_adds_recovery_timeouts(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    rename = operations.alter_column.call_args_list[0]
    assert rename.args == (
        "payment_processing_config",
        "processing_timeout_seconds",
    )
    assert rename.kwargs["new_column_name"] == "authorization_budget_seconds"
    assert isinstance(rename.kwargs["existing_type"], migration.sa.Integer)  # type: ignore[attr-defined]
    assert rename.kwargs["nullable"] is False
    added = [item.args[1] for item in operations.add_column.call_args_list]
    assert all(isinstance(item, Column) for item in added)
    assert [item.name for item in added] == [
        "stale_pending_authorization_seconds",
        "reversal_processing_timeout_seconds",
    ]
    created_checks = {
        item.args[0]: item.args[2]
        for item in operations.create_check_constraint.call_args_list
    }
    assert created_checks == {
        "ck_payment_config_authorization_budget": (
            "authorization_budget_seconds > 0"
        ),
        "ck_payment_config_stale_pending_authorization": (
            "stale_pending_authorization_seconds > 0"
        ),
        "ck_payment_config_stale_pending_after_grace": (
            "stale_pending_authorization_seconds >= reversal_grace_seconds"
        ),
        "ck_payment_config_reversal_processing_timeout": (
            "reversal_processing_timeout_seconds > 0"
        ),
    }


def test_downgrade_restores_processing_timeout(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    assert operations.drop_column.call_args_list == [
        call(
            "payment_processing_config",
            "reversal_processing_timeout_seconds",
        ),
        call(
            "payment_processing_config",
            "stale_pending_authorization_seconds",
        ),
    ]
    rename = operations.alter_column.call_args
    assert rename is not None
    assert rename.args == (
        "payment_processing_config",
        "authorization_budget_seconds",
    )
    assert rename.kwargs["new_column_name"] == "processing_timeout_seconds"
    assert isinstance(rename.kwargs["existing_type"], migration.sa.Integer)  # type: ignore[attr-defined]
    assert rename.kwargs["nullable"] is False
