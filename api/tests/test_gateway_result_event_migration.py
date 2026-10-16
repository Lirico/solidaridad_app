import importlib
from unittest.mock import MagicMock


def test_gateway_result_event_constraint_keeps_outcome_without_attempt_number() -> None:
    migration = importlib.import_module(
        "persistence.migrations.versions.20261015_0012_allow_gateway_result_outcomes"
    )
    operations = MagicMock()
    migration.op = operations  # type: ignore[attr-defined]

    migration.upgrade()  # type: ignore[attr-defined]

    assert migration.revision == "20261015_0012"
    assert migration.down_revision == "20261014_0011"
    created = operations.create_check_constraint.call_args.args
    assert created[:2] == (
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
    )
    assert (
        "event_type <> 'AUTHORIZATION_ATTEMPT' AND attempt_number IS NULL"
        in created[2]
    )
    assert "authorization_outcome IS NULL" not in created[2]
