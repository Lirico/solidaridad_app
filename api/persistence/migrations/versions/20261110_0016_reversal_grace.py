"""delay reversals after the last authorization attempt

Revision ID: 20261110_0016
Revises: 20261105_0015
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261110_0016"
down_revision: str | Sequence[str] | None = "20261105_0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "payment_processing_config",
        sa.Column(
            "reversal_grace_seconds",
            sa.Integer(),
            nullable=False,
            server_default="45",
        ),
    )
    op.create_check_constraint(
        "ck_payment_config_reversal_grace",
        "payment_processing_config",
        "reversal_grace_seconds > 0",
    )
    op.alter_column(
        "payment_processing_config",
        "reversal_grace_seconds",
        existing_type=sa.Integer(),
        server_default=None,
    )

    op.add_column(
        "transactions",
        sa.Column(
            "authorization_last_attempt_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.execute(
        "UPDATE transactions "
        "SET authorization_last_attempt_at = COALESCE(updated_at, created_at)"
    )
    op.alter_column(
        "transactions",
        "authorization_last_attempt_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
    )


def downgrade() -> None:
    op.drop_column("transactions", "authorization_last_attempt_at")
    op.drop_constraint(
        "ck_payment_config_reversal_grace",
        "payment_processing_config",
        type_="check",
    )
    op.drop_column("payment_processing_config", "reversal_grace_seconds")
