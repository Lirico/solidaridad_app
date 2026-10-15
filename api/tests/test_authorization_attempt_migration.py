import importlib

from sqlalchemy import CheckConstraint


def test_authorization_attempt_migration_contract() -> None:
    migration = importlib.import_module(
        "persistence.migrations.versions.20261014_0010_authorization_attempt_events"
    )

    assert migration.revision == "20261014_0010"
    assert migration.down_revision == "20261013_0009"

    constraint = CheckConstraint(
        "(event_type <> 'AUTHORIZATION_ATTEMPT' AND "
        "authorization_outcome IS NULL AND attempt_number IS NULL) OR "
        "(event_type = 'AUTHORIZATION_ATTEMPT' AND "
        "authorization_outcome IN "
        "('APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE') AND "
        "attempt_number >= 1)",
        name="ck_transaction_events_authorization_attempt",
    )
    sql = str(constraint.sqltext)
    assert "AUTHORIZATION_ATTEMPT" in sql
    assert "attempt_number >= 1" in sql
