"""add central recovery review audit actions

Revision ID: 20261014_0013
Revises: 20261014_0012
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261014_0013"
down_revision: str | Sequence[str] | None = "20261014_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "recovery_review_actions",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("processor_job_id", sa.BigInteger(), nullable=False),
        sa.Column("operator_user_id", sa.BigInteger(), nullable=False),
        sa.Column("action_type", sa.String(length=32), nullable=False),
        sa.Column("resolution", sa.String(length=64), nullable=True),
        sa.Column("reason", sa.String(length=512), nullable=False),
        sa.Column("external_reference", sa.String(length=128), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["processor_job_id"], ["processor_jobs.id"]),
        sa.ForeignKeyConstraint(["operator_user_id"], ["users.id"]),
        sa.CheckConstraint(
            "action_type IN ('RESOLUTION', 'MANUAL_RETRY')",
            name="ck_recovery_review_actions_type",
        ),
        sa.CheckConstraint(
            "resolution IS NULL OR resolution IN "
            "('REVERSED_CONFIRMED', 'PROCESSOR_DECLINED', "
            "'ACTIVE_APPROVAL_CONFIRMED')",
            name="ck_recovery_review_actions_resolution",
        ),
    )


def downgrade() -> None:
    op.drop_table("recovery_review_actions")
