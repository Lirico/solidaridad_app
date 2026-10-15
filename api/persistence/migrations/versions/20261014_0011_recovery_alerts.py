"""add durable recovery alerts

Revision ID: 20261014_0011
Revises: 20261014_0010
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261014_0011"
down_revision: str | Sequence[str] | None = "20261014_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "recovery_alerts",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("processor_job_id", sa.BigInteger(), nullable=False),
        sa.Column("cause", sa.String(length=64), nullable=False),
        sa.Column("state", sa.String(length=16), nullable=False),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["processor_job_id"], ["processor_jobs.id"]),
        sa.UniqueConstraint(
            "processor_job_id",
            "cause",
            name="uq_recovery_alerts_job_cause",
        ),
        sa.CheckConstraint("state = 'OPEN'", name="ck_recovery_alerts_state"),
    )
    op.create_index(
        "ix_recovery_alerts_opened",
        "recovery_alerts",
        ["state", "opened_at", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_recovery_alerts_opened", table_name="recovery_alerts")
    op.drop_table("recovery_alerts")
