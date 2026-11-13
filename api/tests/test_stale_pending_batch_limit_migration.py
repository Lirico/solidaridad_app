import importlib
from unittest.mock import MagicMock, call

from sqlalchemy import Column


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261113_0019_stale_pending_batch_limit"
    )


def test_upgrade_adds_a_positive_batch_limit(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    added = operations.add_column.call_args.args[1]
    assert isinstance(added, Column)
    assert added.name == "stale_pending_batch_limit"
    assert added.nullable is False
    check = operations.create_check_constraint.call_args
    assert check.args == (
        "ck_payment_config_stale_pending_batch_limit",
        "payment_processing_config",
        "stale_pending_batch_limit >= 1",
    )


def test_downgrade_drops_the_batch_limit(monkeypatch: object) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    assert operations.drop_constraint.call_args == call(
        "ck_payment_config_stale_pending_batch_limit",
        "payment_processing_config",
        type_="check",
    )
    operations.drop_column.assert_called_once_with(
        "payment_processing_config",
        "stale_pending_batch_limit",
    )
