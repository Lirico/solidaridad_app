"""cap each stale-pending watchdog pass

Revision ID: 20261113_0019
Revises: 20261110_0018
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261113_0019"
down_revision: str | Sequence[str] | None = "20261110_0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "payment_processing_config",
        sa.Column(
            "stale_pending_batch_limit",
            sa.Integer(),
            nullable=False,
            server_default="50",
        ),
    )
    op.create_check_constraint(
        "ck_payment_config_stale_pending_batch_limit",
        "payment_processing_config",
        "stale_pending_batch_limit >= 1",
    )
    op.alter_column(
        "payment_processing_config",
        "stale_pending_batch_limit",
        existing_type=sa.Integer(),
        server_default=None,
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_payment_config_stale_pending_batch_limit",
        "payment_processing_config",
        type_="check",
    )
    op.drop_column("payment_processing_config", "stale_pending_batch_limit")
