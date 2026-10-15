"""add transaction authorization recovery data

Revision ID: 20261013_0008
Revises: 20261006_0007
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261013_0008"
down_revision: str | Sequence[str] | None = "20261006_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OUTCOMES = "'PENDING', 'APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE'"


def upgrade() -> None:
    # Nullable recovery data deliberately leaves historical transactions
    # unrecoverable. Only transactions created by the new application code
    # receive PAN, expiry and an authorization outcome.
    op.add_column(
        "transactions",
        sa.Column("card_number", sa.String(length=19), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("expiration_date", sa.String(length=4), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("authorization_outcome", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column(
            "authorization_attempt_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_transactions_authorization_outcome",
        "transactions",
        f"authorization_outcome IS NULL OR authorization_outcome IN ({_OUTCOMES})",
    )
    op.create_check_constraint(
        "ck_transactions_authorization_attempt_count",
        "transactions",
        "authorization_attempt_count >= 0",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_transactions_authorization_attempt_count",
        "transactions",
        type_="check",
    )
    op.drop_constraint(
        "ck_transactions_authorization_outcome",
        "transactions",
        type_="check",
    )
    op.drop_column("transactions", "authorization_attempt_count")
    op.drop_column("transactions", "authorization_outcome")
    op.drop_column("transactions", "expiration_date")
    op.drop_column("transactions", "card_number")
