"""use surrogate bigint primary keys

Revision ID: 20260717_0003
Revises: 20260716_0002
Create Date: 2026-07-17

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260717_0003"
down_revision: str | Sequence[str] | None = "20260716_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("id_new", sa.BigInteger(), sa.Identity(), nullable=False),
    )
    op.add_column(
        "installations",
        sa.Column("id_new", sa.BigInteger(), sa.Identity(), nullable=False),
    )
    op.add_column(
        "installations",
        sa.Column("installation_id", sa.String(length=128), nullable=True),
    )
    op.execute(
        """
        UPDATE installations
        SET installation_id = COALESCE(NULLIF(BTRIM(terminal_id), ''), BTRIM(id))
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM installations
                WHERE installation_id IS NULL
                   OR LENGTH(installation_id) NOT BETWEEN 1 AND 8
            ) THEN
                RAISE EXCEPTION
                    'installation_id must contain between 1 and 8 characters';
            END IF;
            IF EXISTS (
                SELECT installation_id
                FROM installations
                GROUP BY installation_id
                HAVING COUNT(*) > 1
            ) THEN
                RAISE EXCEPTION 'installation_id values must be unique';
            END IF;
        END
        $$;
        """
    )
    op.alter_column(
        "installations",
        "installation_id",
        existing_type=sa.String(length=128),
        type_=sa.String(length=8),
        nullable=False,
    )

    op.add_column(
        "transactions",
        sa.Column("user_id_new", sa.BigInteger(), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("installation_id_new", sa.BigInteger(), nullable=True),
    )
    op.execute(
        """
        UPDATE transactions AS transaction
        SET user_id_new = users.id_new
        FROM users
        WHERE transaction.user_id = users.id
        """
    )
    op.execute(
        """
        UPDATE transactions AS transaction
        SET installation_id_new = installations.id_new
        FROM installations
        WHERE transaction.installation_id = installations.id
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM transactions
                WHERE user_id_new IS NULL OR installation_id_new IS NULL
            ) THEN
                RAISE EXCEPTION
                    'transactions contain unresolved user or installation references';
            END IF;
        END
        $$;
        """
    )

    op.drop_constraint(
        "uq_transactions_user_idempotency",
        "transactions",
        type_="unique",
    )
    op.drop_index("ix_transactions_user_created_at", table_name="transactions")
    op.drop_constraint(
        "transactions_user_id_fkey",
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        "transactions_installation_id_fkey",
        "transactions",
        type_="foreignkey",
    )
    op.drop_column("transactions", "user_id")
    op.drop_column("transactions", "installation_id")
    op.alter_column("transactions", "user_id_new", new_column_name="user_id")
    op.alter_column(
        "transactions",
        "installation_id_new",
        new_column_name="installation_id",
    )
    op.alter_column("transactions", "user_id", nullable=False)
    op.alter_column("transactions", "installation_id", nullable=False)

    op.drop_constraint("users_pkey", "users", type_="primary")
    op.drop_column("users", "id")
    op.alter_column("users", "id_new", new_column_name="id")
    op.create_primary_key("users_pkey", "users", ["id"])

    op.drop_constraint("installations_pkey", "installations", type_="primary")
    op.drop_column("installations", "id")
    op.drop_column("installations", "terminal_id")
    op.alter_column("installations", "id_new", new_column_name="id")
    op.create_primary_key("installations_pkey", "installations", ["id"])
    op.create_unique_constraint(
        "uq_installations_installation_id",
        "installations",
        ["installation_id"],
    )

    op.create_foreign_key(
        "transactions_user_id_fkey",
        "transactions",
        "users",
        ["user_id"],
        ["id"],
    )
    op.create_foreign_key(
        "transactions_installation_id_fkey",
        "transactions",
        "installations",
        ["installation_id"],
        ["id"],
    )
    op.create_unique_constraint(
        "uq_transactions_user_idempotency",
        "transactions",
        ["user_id", "idempotency_key"],
    )
    op.create_index(
        "ix_transactions_user_created_at",
        "transactions",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "id_old",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
    )
    op.add_column(
        "installations",
        sa.Column("id_old", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "installations",
        sa.Column("terminal_id", sa.String(length=8), nullable=True),
    )
    op.execute(
        """
        UPDATE installations
        SET id_old = installation_id, terminal_id = installation_id
        """
    )
    op.alter_column("installations", "id_old", nullable=False)

    op.add_column(
        "transactions",
        sa.Column(
            "user_id_old",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.add_column(
        "transactions",
        sa.Column("installation_id_old", sa.String(length=128), nullable=True),
    )
    op.execute(
        """
        UPDATE transactions AS transaction
        SET user_id_old = users.id_old
        FROM users
        WHERE transaction.user_id = users.id
        """
    )
    op.execute(
        """
        UPDATE transactions AS transaction
        SET installation_id_old = installations.id_old
        FROM installations
        WHERE transaction.installation_id = installations.id
        """
    )
    op.alter_column("transactions", "user_id_old", nullable=False)
    op.alter_column("transactions", "installation_id_old", nullable=False)

    op.drop_constraint(
        "uq_transactions_user_idempotency",
        "transactions",
        type_="unique",
    )
    op.drop_index("ix_transactions_user_created_at", table_name="transactions")
    op.drop_constraint(
        "transactions_user_id_fkey",
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        "transactions_installation_id_fkey",
        "transactions",
        type_="foreignkey",
    )
    op.drop_column("transactions", "user_id")
    op.drop_column("transactions", "installation_id")
    op.alter_column("transactions", "user_id_old", new_column_name="user_id")
    op.alter_column(
        "transactions",
        "installation_id_old",
        new_column_name="installation_id",
    )

    op.drop_constraint("users_pkey", "users", type_="primary")
    op.drop_column("users", "id")
    op.alter_column("users", "id_old", new_column_name="id")
    op.create_primary_key("users_pkey", "users", ["id"])

    op.drop_constraint(
        "uq_installations_installation_id",
        "installations",
        type_="unique",
    )
    op.drop_constraint("installations_pkey", "installations", type_="primary")
    op.drop_column("installations", "id")
    op.drop_column("installations", "installation_id")
    op.alter_column("installations", "id_old", new_column_name="id")
    op.create_primary_key("installations_pkey", "installations", ["id"])

    op.create_foreign_key(
        "transactions_user_id_fkey",
        "transactions",
        "users",
        ["user_id"],
        ["id"],
    )
    op.create_foreign_key(
        "transactions_installation_id_fkey",
        "transactions",
        "installations",
        ["installation_id"],
        ["id"],
    )
    op.create_unique_constraint(
        "uq_transactions_user_idempotency",
        "transactions",
        ["user_id", "idempotency_key"],
    )
    op.create_index(
        "ix_transactions_user_created_at",
        "transactions",
        ["user_id", "created_at"],
    )
