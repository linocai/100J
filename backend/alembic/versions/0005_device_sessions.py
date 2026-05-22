"""device sessions

Revision ID: 0005_device_sessions
Revises: 0004_seed_demo_source
Create Date: 2026-05-21
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "0005_device_sessions"
down_revision: Union[str, None] = "0004_seed_demo_source"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_names(inspector) -> set:
    return set(inspector.get_table_names())


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "device_sessions" in _table_names(inspector):
        return

    op.create_table(
        "device_sessions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("device_id", sa.String(length=64), nullable=False),
        sa.Column("device_name", sa.String(length=128), nullable=True),
        sa.Column("platform", sa.String(length=16), nullable=False, server_default="macos"),
        sa.Column("refresh_token_hash", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_unique_constraint(
        "uq_device_sessions_device_id",
        "device_sessions",
        ["device_id"],
    )
    op.create_index(
        "ix_device_sessions_user_id",
        "device_sessions",
        ["user_id"],
    )
    op.create_index(
        "ix_device_sessions_active",
        "device_sessions",
        ["device_id", "revoked_at"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "device_sessions" not in _table_names(inspector):
        return
    op.drop_index("ix_device_sessions_active", table_name="device_sessions")
    op.drop_index("ix_device_sessions_user_id", table_name="device_sessions")
    op.drop_constraint("uq_device_sessions_device_id", "device_sessions", type_="unique")
    op.drop_table("device_sessions")
