"""add administrative batch closes

Revision ID: 20261006_0007
Revises: 20260807_0006
Create Date: 2026-10-06
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261006_0007"
down_revision: str | Sequence[str] | None = "20260807_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "batch_closes",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("installation_id", sa.BigInteger(), nullable=False),
        sa.Column("terminal_id", sa.String(length=8), nullable=False),
        sa.Column("closed_by_user_id", sa.BigInteger(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column(
            "closed_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["installation_id"], ["installations.id"]),
        sa.ForeignKeyConstraint(["closed_by_user_id"], ["users.id"]),
        sa.UniqueConstraint(
            "installation_id",
            "idempotency_key",
            name="uq_batch_closes_installation_idempotency",
        ),
    )
    op.add_column(
        "transactions",
        sa.Column("batch_close_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "transactions_batch_close_id_fkey",
        "transactions",
        "batch_closes",
        ["batch_close_id"],
        ["id"],
    )
    op.create_index(
        "ix_transactions_terminal_current",
        "transactions",
        ["terminal_id", "created_at", "id"],
        postgresql_where=sa.text("batch_close_id IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_transactions_terminal_current", table_name="transactions")
    op.drop_constraint(
        "transactions_batch_close_id_fkey",
        "transactions",
        type_="foreignkey",
    )
    op.drop_column("transactions", "batch_close_id")
    op.drop_table("batch_closes")
