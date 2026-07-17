"""transactions, counters, installation terminal_id

Revision ID: 20260716_0002
Revises: 20260715_0001
Create Date: 2026-07-16

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260716_0002"
down_revision: Union[str, Sequence[str], None] = "20260715_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "installations",
        sa.Column("terminal_id", sa.String(length=8), nullable=True),
    )

    op.create_table(
        "transaction_number_counters",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("business_date", sa.Date(), nullable=False),
        sa.Column("last_value", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "business_date",
            name="uq_transaction_number_counters_business_date",
        ),
    )

    op.create_table(
        "transactions",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("transaction_number", sa.String(length=14), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("installation_id", sa.String(length=128), nullable=False),
        sa.Column("terminal_id", sa.String(length=8), nullable=False),
        sa.Column("product", sa.String(length=32), nullable=False),
        sa.Column("processor_product_code", sa.String(length=3), nullable=False),
        sa.Column("amount_minor", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("card_last4", sa.String(length=4), nullable=False),
        sa.Column("stan", sa.String(length=6), nullable=True),
        sa.Column("auth_id", sa.String(length=32), nullable=True),
        sa.Column("retrieval_reference", sa.String(length=32), nullable=True),
        sa.Column("processor_response_code", sa.String(length=8), nullable=True),
        sa.Column("user_message", sa.String(length=512), nullable=True),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["installation_id"], ["installations.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "transaction_number",
            name="uq_transactions_transaction_number",
        ),
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_transactions_user_idempotency",
        ),
    )
    op.create_index(
        "ix_transactions_user_created_at",
        "transactions",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_transactions_user_created_at", table_name="transactions")
    op.drop_table("transactions")
    op.drop_table("transaction_number_counters")
    op.drop_column("installations", "terminal_id")
