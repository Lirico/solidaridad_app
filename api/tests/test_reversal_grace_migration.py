import importlib
from unittest.mock import MagicMock


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261110_0016_reversal_grace"
    )


def test_migration_adds_reversal_grace_and_attempt_timestamp(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    added = [call.args[1] for call in operations.add_column.call_args_list]
    assert [column.name for column in added] == [
        "reversal_grace_seconds",
        "authorization_last_attempt_at",
    ]
    assert added[0].server_default.arg == "45"
    assert added[1].nullable
    operations.create_check_constraint.assert_called_once_with(
        "ck_payment_config_reversal_grace",
        "payment_processing_config",
        "reversal_grace_seconds > 0",
    )
    operations.execute.assert_called_once_with(
        "UPDATE transactions "
        "SET authorization_last_attempt_at = COALESCE(updated_at, created_at)"
    )


def test_migration_downgrade_removes_attempt_timestamp_and_grace(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    assert [call.args[1] for call in operations.drop_column.call_args_list] == [
        "authorization_last_attempt_at",
        "reversal_grace_seconds",
    ]
    operations.drop_constraint.assert_called_once_with(
        "ck_payment_config_reversal_grace",
        "payment_processing_config",
        type_="check",
    )
