"""allow authorization outcomes on gateway result events

Revision ID: 20261015_0012
Revises: 20261014_0011
Create Date: 2026-10-15
"""

from collections.abc import Sequence

from alembic import op

revision: str = "20261015_0012"
down_revision: str | Sequence[str] | None = "20261014_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_CONSTRAINT = (
    "(event_type = 'AUTHORIZATION_ATTEMPT' AND "
    "authorization_outcome IN "
    "('APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE') AND "
    "attempt_number >= 1) OR "
    "(event_type <> 'AUTHORIZATION_ATTEMPT' AND attempt_number IS NULL)"
)

_PREVIOUS_CONSTRAINT = (
    "(event_type <> 'AUTHORIZATION_ATTEMPT' AND "
    "authorization_outcome IS NULL AND attempt_number IS NULL) OR "
    "(event_type = 'AUTHORIZATION_ATTEMPT' AND "
    "authorization_outcome IN "
    "('APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE') AND "
    "attempt_number >= 1)"
)


def upgrade() -> None:
    op.drop_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        type_="check",
    )
    op.create_check_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        _CONSTRAINT,
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        type_="check",
    )
    op.create_check_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        _PREVIOUS_CONSTRAINT,
    )
