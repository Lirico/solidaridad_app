"""add processor_ticket and void_idempotency_key

Revision ID: 20260807_0005
Revises: 20260806_0004
Create Date: 2026-08-07

Stores ISO DE62 ticket for void lookup and void Idempotency-Key.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260807_0005"
down_revision: str | Sequence[str] | None = "20260806_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "transactions",
        sa.Column("processor_ticket", sa.String(length=24), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("void_idempotency_key", sa.String(length=128), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("transactions", "void_idempotency_key")
    op.drop_column("transactions", "processor_ticket")
