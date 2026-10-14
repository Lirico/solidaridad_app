"""record authorization attempt outcomes

Revision ID: 20261014_0010
Revises: 20261013_0009
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261014_0010"
down_revision: str | Sequence[str] | None = "20261013_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "transaction_status_events",
        sa.Column("authorization_outcome", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "transaction_status_events",
        sa.Column("attempt_number", sa.Integer(), nullable=True),
    )
    op.create_check_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        "(event_type <> 'AUTHORIZATION_ATTEMPT' AND "
        "authorization_outcome IS NULL AND attempt_number IS NULL) OR "
        "(event_type = 'AUTHORIZATION_ATTEMPT' AND "
        "authorization_outcome IN "
        "('APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE') AND "
        "attempt_number >= 1)",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_transaction_events_authorization_attempt",
        "transaction_status_events",
        type_="check",
    )
    op.drop_column("transaction_status_events", "attempt_number")
    op.drop_column("transaction_status_events", "authorization_outcome")
