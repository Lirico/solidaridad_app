import importlib
from unittest.mock import MagicMock

from sqlalchemy import CheckConstraint, ForeignKeyConstraint, UniqueConstraint


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261014_0011_recovery_alerts"
    )


def test_migration_creates_deduplicated_open_recovery_alerts(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    call = operations.create_table.call_args
    assert call.args[0] == "recovery_alerts"
    table_items = call.args[1:]
    constraint_names = {
        item.name
        for item in table_items
        if isinstance(item, (CheckConstraint, UniqueConstraint))
    }
    assert constraint_names == {
        "ck_recovery_alerts_state",
        "uq_recovery_alerts_job_cause",
    }
    foreign_keys = [
        item for item in table_items if isinstance(item, ForeignKeyConstraint)
    ]
    assert len(foreign_keys) == 1
    assert list(foreign_keys[0].column_keys) == ["processor_job_id"]
    operations.create_index.assert_called_once_with(
        "ix_recovery_alerts_opened",
        "recovery_alerts",
        ["state", "opened_at", "id"],
    )


def test_migration_downgrade_removes_recovery_alerts(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    operations.drop_index.assert_called_once_with(
        "ix_recovery_alerts_opened",
        table_name="recovery_alerts",
    )
    operations.drop_table.assert_called_once_with("recovery_alerts")
