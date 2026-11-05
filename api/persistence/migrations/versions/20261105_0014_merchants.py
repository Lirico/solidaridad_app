"""add merchants and associate accounts

Revision ID: 20261105_0014
Revises: 20261022_0013
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261105_0014"
down_revision: str | Sequence[str] | None = "20261022_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "merchants",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("code", sa.String(32), nullable=False, unique=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("address", sa.String(255), nullable=False),
        sa.Column("city", sa.String(255), nullable=False),
        sa.Column("tax_id", sa.String(32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.add_column("users", sa.Column("merchant_id", sa.BigInteger(), nullable=True))
    op.create_foreign_key(
        "fk_users_merchant_id", "users", "merchants", ["merchant_id"], ["id"]
    )


def downgrade() -> None:
    op.drop_constraint("fk_users_merchant_id", "users", type_="foreignkey")
    op.drop_column("users", "merchant_id")
    op.drop_table("merchants")
