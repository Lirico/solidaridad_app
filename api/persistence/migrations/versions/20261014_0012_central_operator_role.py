"""add central operator role

Revision ID: 20261014_0012
Revises: 20261014_0011
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261014_0012"
down_revision: str | Sequence[str] | None = "20261014_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "role",
            sa.String(length=32),
            server_default="TERMINAL",
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_users_role",
        "users",
        "role IN ('TERMINAL', 'CENTRAL_OPERATOR')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.drop_column("users", "role")
