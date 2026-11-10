"""separate authorization and recovery timeouts

Revision ID: 20261110_0018
Revises: 20261110_0017
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261110_0018"
down_revision: str | Sequence[str] | None = "20261110_0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        "ck_payment_config_processing_timeout",
        "payment_processing_config",
        type_="check",
    )
    op.alter_column(
        "payment_processing_config",
        "processing_timeout_seconds",
        new_column_name="authorization_budget_seconds",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.create_check_constraint(
        "ck_payment_config_authorization_budget",
        "payment_processing_config",
        "authorization_budget_seconds > 0",
    )
    op.add_column(
        "payment_processing_config",
        sa.Column(
            "stale_pending_authorization_seconds",
            sa.Integer(),
            nullable=False,
            server_default="45",
        ),
    )
    op.add_column(
        "payment_processing_config",
        sa.Column(
            "reversal_processing_timeout_seconds",
            sa.Integer(),
            nullable=False,
            server_default="60",
        ),
    )
    op.create_check_constraint(
        "ck_payment_config_stale_pending_authorization",
        "payment_processing_config",
        "stale_pending_authorization_seconds > 0",
    )
    op.create_check_constraint(
        "ck_payment_config_stale_pending_after_grace",
        "payment_processing_config",
        "stale_pending_authorization_seconds >= reversal_grace_seconds",
    )
    op.create_check_constraint(
        "ck_payment_config_reversal_processing_timeout",
        "payment_processing_config",
        "reversal_processing_timeout_seconds > 0",
    )
    op.alter_column(
        "payment_processing_config",
        "stale_pending_authorization_seconds",
        existing_type=sa.Integer(),
        server_default=None,
    )
    op.alter_column(
        "payment_processing_config",
        "reversal_processing_timeout_seconds",
        existing_type=sa.Integer(),
        server_default=None,
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_payment_config_reversal_processing_timeout",
        "payment_processing_config",
        type_="check",
    )
    op.drop_constraint(
        "ck_payment_config_stale_pending_after_grace",
        "payment_processing_config",
        type_="check",
    )
    op.drop_constraint(
        "ck_payment_config_stale_pending_authorization",
        "payment_processing_config",
        type_="check",
    )
    op.drop_column(
        "payment_processing_config", "reversal_processing_timeout_seconds"
    )
    op.drop_column(
        "payment_processing_config", "stale_pending_authorization_seconds"
    )
    op.drop_constraint(
        "ck_payment_config_authorization_budget",
        "payment_processing_config",
        type_="check",
    )
    op.alter_column(
        "payment_processing_config",
        "authorization_budget_seconds",
        new_column_name="processing_timeout_seconds",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.create_check_constraint(
        "ck_payment_config_processing_timeout",
        "payment_processing_config",
        "processing_timeout_seconds > 0",
    )
