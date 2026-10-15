"""add durable processor jobs and payment processing config

Revision ID: 20261013_0009
Revises: 20261013_0008
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261013_0009"
down_revision: str | Sequence[str] | None = "20261013_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "processor_jobs",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("transaction_id", sa.BigInteger(), nullable=False),
        sa.Column("operation_type", sa.String(length=16), nullable=False),
        sa.Column("state", sa.String(length=16), nullable=False),
        sa.Column("result", sa.String(length=64), nullable=True),
        sa.Column(
            "attempt_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("worker_id", sa.String(length=128), nullable=True),
        sa.Column("claim_token", sa.Uuid(), nullable=True),
        sa.Column("processing_started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("original_stan", sa.String(length=6), nullable=True),
        sa.Column("original_ticket", sa.String(length=24), nullable=True),
        sa.Column("reversal_stan", sa.String(length=6), nullable=True),
        sa.Column("last_error_code", sa.String(length=64), nullable=True),
        sa.Column(
            "last_error_detail_sanitized",
            sa.String(length=512),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"]),
        sa.UniqueConstraint(
            "transaction_id",
            "operation_type",
            name="uq_processor_jobs_transaction_operation",
        ),
        sa.UniqueConstraint(
            "transaction_id",
            "reversal_stan",
            name="uq_processor_jobs_transaction_reversal_stan",
        ),
        sa.CheckConstraint(
            "operation_type IN ('AUTHORIZE', 'REVERSE')",
            name="ck_processor_jobs_operation_type",
        ),
        sa.CheckConstraint(
            "state IN ('READY', 'PROCESSING', 'RETRY', 'COMPLETED', "
            "'MANUAL_REVIEW')",
            name="ck_processor_jobs_state",
        ),
        sa.CheckConstraint(
            "attempt_count >= 0",
            name="ck_processor_jobs_attempt_count",
        ),
        sa.CheckConstraint(
            "state <> 'PROCESSING' OR (worker_id IS NOT NULL AND "
            "claim_token IS NOT NULL AND processing_started_at IS NOT NULL)",
            name="ck_processor_jobs_processing_claim",
        ),
        sa.CheckConstraint(
            "state <> 'COMPLETED' OR (result IS NOT NULL AND completed_at IS NOT NULL)",
            name="ck_processor_jobs_completed_result",
        ),
    )
    op.create_index(
        "ix_processor_jobs_available",
        "processor_jobs",
        ["state", "next_attempt_at", "id"],
        postgresql_where=sa.text("state IN ('READY', 'RETRY')"),
    )

    op.create_table(
        "payment_processing_config",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("config_name", sa.String(length=64), nullable=False, unique=True),
        sa.Column("max_authorization_attempts", sa.Integer(), nullable=False),
        sa.Column("authorization_initial_delay_ms", sa.Integer(), nullable=False),
        sa.Column("authorization_max_delay_ms", sa.Integer(), nullable=False),
        sa.Column(
            "authorization_backoff_multiplier",
            sa.Numeric(10, 4),
            nullable=False,
        ),
        sa.Column("max_reversal_attempts", sa.Integer(), nullable=False),
        sa.Column("reversal_initial_delay_seconds", sa.Integer(), nullable=False),
        sa.Column("reversal_max_delay_seconds", sa.Integer(), nullable=False),
        sa.Column(
            "reversal_backoff_multiplier",
            sa.Numeric(10, 4),
            nullable=False,
        ),
        sa.Column("jitter_percentage", sa.Integer(), nullable=False),
        sa.Column("processing_timeout_seconds", sa.Integer(), nullable=False),
        sa.Column(
            "worker_poll_interval_seconds",
            sa.Numeric(10, 4),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "max_authorization_attempts >= 1",
            name="ck_payment_config_max_authorization_attempts",
        ),
        sa.CheckConstraint(
            "authorization_initial_delay_ms >= 0",
            name="ck_payment_config_authorization_initial_delay",
        ),
        sa.CheckConstraint(
            "authorization_max_delay_ms >= authorization_initial_delay_ms",
            name="ck_payment_config_authorization_max_delay",
        ),
        sa.CheckConstraint(
            "authorization_backoff_multiplier >= 1",
            name="ck_payment_config_authorization_backoff",
        ),
        sa.CheckConstraint(
            "max_reversal_attempts >= 1",
            name="ck_payment_config_max_reversal_attempts",
        ),
        sa.CheckConstraint(
            "reversal_initial_delay_seconds >= 0",
            name="ck_payment_config_reversal_initial_delay",
        ),
        sa.CheckConstraint(
            "reversal_max_delay_seconds >= reversal_initial_delay_seconds",
            name="ck_payment_config_reversal_max_delay",
        ),
        sa.CheckConstraint(
            "reversal_backoff_multiplier >= 1",
            name="ck_payment_config_reversal_backoff",
        ),
        sa.CheckConstraint(
            "jitter_percentage BETWEEN 0 AND 100",
            name="ck_payment_config_jitter_percentage",
        ),
        sa.CheckConstraint(
            "processing_timeout_seconds > 0",
            name="ck_payment_config_processing_timeout",
        ),
        sa.CheckConstraint(
            "worker_poll_interval_seconds > 0",
            name="ck_payment_config_worker_poll_interval",
        ),
    )
    op.bulk_insert(
        sa.table(
            "payment_processing_config",
            sa.column("config_name", sa.String()),
            sa.column("max_authorization_attempts", sa.Integer()),
            sa.column("authorization_initial_delay_ms", sa.Integer()),
            sa.column("authorization_max_delay_ms", sa.Integer()),
            sa.column("authorization_backoff_multiplier", sa.Numeric()),
            sa.column("max_reversal_attempts", sa.Integer()),
            sa.column("reversal_initial_delay_seconds", sa.Integer()),
            sa.column("reversal_max_delay_seconds", sa.Integer()),
            sa.column("reversal_backoff_multiplier", sa.Numeric()),
            sa.column("jitter_percentage", sa.Integer()),
            sa.column("processing_timeout_seconds", sa.Integer()),
            sa.column("worker_poll_interval_seconds", sa.Numeric()),
        ),
        [
            {
                "config_name": "default",
                "max_authorization_attempts": 3,
                "authorization_initial_delay_ms": 100,
                "authorization_max_delay_ms": 500,
                "authorization_backoff_multiplier": 2,
                "max_reversal_attempts": 5,
                "reversal_initial_delay_seconds": 5,
                "reversal_max_delay_seconds": 300,
                "reversal_backoff_multiplier": 2,
                "jitter_percentage": 20,
                "processing_timeout_seconds": 60,
                "worker_poll_interval_seconds": 1,
            }
        ],
    )


def downgrade() -> None:
    op.drop_table("payment_processing_config")
    op.drop_index("ix_processor_jobs_available", table_name="processor_jobs")
    op.drop_table("processor_jobs")
