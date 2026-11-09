"""add durable void operations

Revision ID: 20261022_0013
Revises: 20261015_0012
Create Date: 2026-10-22
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261022_0013"
down_revision: str | Sequence[str] | None = "20261015_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "void_operations",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("transaction_id", sa.BigInteger(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column("stan", sa.String(length=6), nullable=False),
        sa.Column("void_ticket", sa.String(length=24), nullable=False),
        sa.Column("original_ticket", sa.String(length=24), nullable=False),
        sa.Column("outcome", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("processor_response_code", sa.String(length=8), nullable=True),
        sa.Column("user_message", sa.String(length=512), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"]),
        sa.UniqueConstraint(
            "transaction_id",
            "idempotency_key",
            name="uq_void_operations_transaction_idempotency",
        ),
        sa.CheckConstraint(
            "outcome IN ('PENDING', 'APPROVED', 'DECLINED', 'NOT_SENT', 'INDETERMINATE')",
            name="ck_void_operations_outcome",
        ),
        sa.CheckConstraint(
            "status IN ('PENDING', 'VOIDED', 'DECLINED', 'FAILED', 'UNDER_REVIEW')",
            name="ck_void_operations_status",
        ),
    )
    op.create_index(
        "uq_void_operations_active_transaction",
        "void_operations",
        ["transaction_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('PENDING', 'UNDER_REVIEW')"),
    )
    op.create_table(
        "void_operation_alerts",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("void_operation_id", sa.BigInteger(), nullable=False),
        sa.Column("cause", sa.String(length=64), nullable=False),
        sa.Column("state", sa.String(length=16), nullable=False),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["void_operation_id"], ["void_operations.id"]),
        sa.UniqueConstraint(
            "void_operation_id",
            "cause",
            name="uq_void_operation_alerts_operation_cause",
        ),
        sa.CheckConstraint("state = 'OPEN'", name="ck_void_operation_alerts_state"),
    )
    op.create_index(
        "ix_void_operation_alerts_opened",
        "void_operation_alerts",
        ["state", "opened_at", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_void_operation_alerts_opened", table_name="void_operation_alerts")
    op.drop_table("void_operation_alerts")
    op.drop_index("uq_void_operations_active_transaction", table_name="void_operations")
    op.drop_table("void_operations")
