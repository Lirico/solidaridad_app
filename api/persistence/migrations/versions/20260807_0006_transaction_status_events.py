"""add transaction_status_events

Revision ID: 20260807_0006
Revises: 20260807_0005
Create Date: 2026-08-07

Append-only status history for support/audit (no API exposure yet).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260807_0006"
down_revision: str | Sequence[str] | None = "20260807_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "transaction_status_events",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("transaction_id", sa.BigInteger(), nullable=False),
        sa.Column("from_status", sa.String(length=16), nullable=True),
        sa.Column("to_status", sa.String(length=16), nullable=False),
        sa.Column("event_type", sa.String(length=32), nullable=False),
        sa.Column("actor_type", sa.String(length=16), nullable=False),
        sa.Column("actor_user_id", sa.BigInteger(), nullable=True),
        sa.Column("processor_response_code", sa.String(length=8), nullable=True),
        sa.Column("user_message", sa.String(length=512), nullable=True),
        sa.Column("idempotency_key", sa.String(length=128), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"]),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
    )
    op.create_index(
        "ix_transaction_status_events_transaction_id_created_at",
        "transaction_status_events",
        ["transaction_id", "created_at"],
    )
    op.create_index(
        "ix_transaction_status_events_created_at",
        "transaction_status_events",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_transaction_status_events_created_at",
        table_name="transaction_status_events",
    )
    op.drop_index(
        "ix_transaction_status_events_transaction_id_created_at",
        table_name="transaction_status_events",
    )
    op.drop_table("transaction_status_events")
