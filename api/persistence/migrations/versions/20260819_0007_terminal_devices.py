"""add terminal_devices

Revision ID: 20260819_0007
Revises: 20260807_0006
Create Date: 2026-08-19

Maps a hardware logical_device_id to the processor terminal id (installation_id).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260819_0007"
down_revision: str | Sequence[str] | None = "20260807_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "terminal_devices",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("logical_device_id", sa.String(length=128), nullable=False),
        sa.Column("installation_id", sa.String(length=8), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("logical_device_id", name="uq_terminal_devices_logical_device_id"),
        sa.UniqueConstraint("installation_id", name="uq_terminal_devices_installation_id"),
    )


def downgrade() -> None:
    op.drop_table("terminal_devices")
