"""agent pending confirmations

Revision ID: 0002_agent_pending_confirmations
Revises: 0001_initial_schema
Create Date: 2026-05-18
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "0002_agent_pending_confirmations"
down_revision: Union[str, None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if inspector.has_table("agent_pending_confirmations"):
        return

    op.create_table(
        "agent_pending_confirmations",
        sa.Column("token", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("command", sa.String(length=128), nullable=False),
        sa.Column("arguments", sa.JSON(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "idx_agent_pending_confirmations_user_id",
        "agent_pending_confirmations",
        ["user_id"],
    )
    op.create_index(
        "idx_agent_pending_confirmations_expires_at",
        "agent_pending_confirmations",
        ["expires_at"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if not inspector.has_table("agent_pending_confirmations"):
        return

    op.drop_index("idx_agent_pending_confirmations_expires_at", table_name="agent_pending_confirmations")
    op.drop_index("idx_agent_pending_confirmations_user_id", table_name="agent_pending_confirmations")
    op.drop_table("agent_pending_confirmations")
