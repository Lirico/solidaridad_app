"""widen card columns so ciphertext fits

Revision ID: 20261112_0019
Revises: 20261110_0018
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261112_0019"
down_revision: str | Sequence[str] | None = "20261110_0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "transactions",
        "card_number",
        existing_type=sa.String(length=19),
        type_=sa.String(length=255),
        existing_nullable=True,
    )
    op.alter_column(
        "transactions",
        "expiration_date",
        existing_type=sa.String(length=4),
        type_=sa.String(length=255),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "transactions",
        "card_number",
        existing_type=sa.String(length=255),
        type_=sa.String(length=19),
        existing_nullable=True,
    )
    op.alter_column(
        "transactions",
        "expiration_date",
        existing_type=sa.String(length=255),
        type_=sa.String(length=4),
        existing_nullable=True,
    )
