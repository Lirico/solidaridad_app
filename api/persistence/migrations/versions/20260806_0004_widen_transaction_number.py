"""widen transaction_number to 24 chars

Revision ID: 20260806_0004
Revises: 20260717_0003
Create Date: 2026-08-06

Supports OP-YYMMDD-NNNNNNNN (18 chars typical) with headroom if the
daily sequence ever exceeds 8 digits.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260806_0004"
down_revision: str | Sequence[str] | None = "20260717_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "transactions",
        "transaction_number",
        existing_type=sa.String(length=14),
        type_=sa.String(length=24),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "transactions",
        "transaction_number",
        existing_type=sa.String(length=24),
        type_=sa.String(length=14),
        existing_nullable=False,
    )
