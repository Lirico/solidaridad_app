import importlib
from unittest.mock import MagicMock

import pytest


def test_migration_refuses_to_invent_merchants(monkeypatch: pytest.MonkeyPatch) -> None:
    migration = importlib.import_module(
        "persistence.migrations.versions.20261105_0015_require_user_merchant"
    )
    operations = MagicMock()
    operations.get_bind.return_value.scalar.return_value = 2
    monkeypatch.setattr(migration, "op", operations)
    with pytest.raises(RuntimeError, match="Asigne un comercio"):
        migration.upgrade()
    operations.alter_column.assert_not_called()


def test_migration_requires_merchant_when_all_users_are_assigned(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    migration = importlib.import_module(
        "persistence.migrations.versions.20261105_0015_require_user_merchant"
    )
    operations = MagicMock()
    operations.get_bind.return_value.scalar.return_value = 0
    monkeypatch.setattr(migration, "op", operations)
    migration.upgrade()
    assert operations.alter_column.call_args.kwargs["nullable"] is False
