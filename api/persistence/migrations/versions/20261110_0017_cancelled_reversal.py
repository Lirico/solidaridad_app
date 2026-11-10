"""add cancelled state for reversals resolved before send

Revision ID: 20261110_0017
Revises: 20261110_0016
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261110_0017"
down_revision: str | Sequence[str] | None = "20261110_0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint("ck_processor_jobs_state", "processor_jobs", type_="check")
    op.create_check_constraint(
        "ck_processor_jobs_state",
        "processor_jobs",
        "state IN ('READY', 'PROCESSING', 'RETRY', 'COMPLETED', "
        "'CANCELLED', 'MANUAL_REVIEW')",
    )
    op.create_check_constraint(
        "ck_processor_jobs_cancelled_reason",
        "processor_jobs",
        "state <> 'CANCELLED' OR (result IS NOT NULL AND completed_at IS NOT NULL)",
    )


def downgrade() -> None:
    op.execute(
        "UPDATE processor_jobs SET state = 'COMPLETED' WHERE state = 'CANCELLED'"
    )
    op.drop_constraint(
        "ck_processor_jobs_cancelled_reason", "processor_jobs", type_="check"
    )
    op.drop_constraint("ck_processor_jobs_state", "processor_jobs", type_="check")
    op.create_check_constraint(
        "ck_processor_jobs_state",
        "processor_jobs",
        "state IN ('READY', 'PROCESSING', 'RETRY', 'COMPLETED', 'MANUAL_REVIEW')",
    )
