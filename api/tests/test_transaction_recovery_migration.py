import importlib
from unittest.mock import MagicMock


def _migration() -> object:
    return importlib.import_module(
        "persistence.migrations.versions.20261013_0008_transaction_recovery_data"
    )


def test_recovery_migration_adds_nullable_historical_data_and_constraints(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    columns = [call.args[1] for call in operations.add_column.call_args_list]
    by_name = {column.name: column for column in columns}
    assert by_name["card_number"].nullable
    assert by_name["expiration_date"].nullable
    assert by_name["authorization_outcome"].nullable
    assert not by_name["authorization_attempt_count"].nullable
    constraint_names = {
        call.args[0] for call in operations.create_check_constraint.call_args_list
    }
    assert constraint_names == {
        "ck_transactions_authorization_outcome",
        "ck_transactions_authorization_attempt_count",
    }


def test_recovery_migration_downgrade_removes_all_recovery_columns(
    monkeypatch: object,
) -> None:
    migration = _migration()
    operations = MagicMock()
    monkeypatch.setattr(migration, "op", operations)  # type: ignore[attr-defined]

    migration.downgrade()  # type: ignore[attr-defined]

    dropped = [call.args[1] for call in operations.drop_column.call_args_list]
    assert dropped == [
        "authorization_attempt_count",
        "authorization_outcome",
        "expiration_date",
        "card_number",
    ]
