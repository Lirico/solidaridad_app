"""login attempt counter

Revision ID: 20261113_0020
Revises: 20261113_0019
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261113_0020"
down_revision: str | Sequence[str] | None = "20261113_0019"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "login_attempts",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("username", sa.String(length=320), nullable=False),
        sa.Column("attempted_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_login_attempts_username_attempted_at",
        "login_attempts",
        ["username", "attempted_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_login_attempts_username_attempted_at",
        table_name="login_attempts",
    )
    op.drop_table("login_attempts")
