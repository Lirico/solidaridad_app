"""require a merchant for every account

Revision ID: 20261105_0015
Revises: 20261105_0014
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261105_0015"
down_revision: str | Sequence[str] | None = "20261105_0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    connection = op.get_bind()
    missing = connection.scalar(
        sa.text("SELECT count(*) FROM users WHERE merchant_id IS NULL")
    )
    if missing:
        raise RuntimeError(
            "Asigne un comercio a todas las cuentas antes de aplicar 20261105_0015. "
            "Ejecute primero alembic upgrade 20261105_0014 y configure merchants y users."
        )
    op.alter_column(
        "users", "merchant_id", existing_type=sa.BigInteger(), nullable=False
    )


def downgrade() -> None:
    op.alter_column(
        "users", "merchant_id", existing_type=sa.BigInteger(), nullable=True
    )
