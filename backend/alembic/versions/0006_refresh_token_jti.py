"""refresh token jti registry

Revision ID: 0006_refresh_token_jti
Revises: 0005_device_sessions
Create Date: 2026-05-24

P2-3 (#19): persistent record of issued JWT refresh tokens so /auth/refresh
can rotate-and-blacklist instead of replaying the same long-lived token
forever. Device-bound refresh tokens stay in ``device_sessions`` — this
table is JWT-only.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "0006_refresh_token_jti"
down_revision: Union[str, None] = "0005_device_sessions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_names(inspector) -> set:
    return set(inspector.get_table_names())


def _index_names(inspector, table_name: str) -> set:
    try:
        return {idx["name"] for idx in inspector.get_indexes(table_name)}
    except Exception:
        return set()


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "refresh_token_jti" in _table_names(inspector):
        return

    op.create_table(
        "refresh_token_jti",
        sa.Column("jti", sa.String(length=64), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(length=36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "issued_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_refresh_token_jti_user_id",
        "refresh_token_jti",
        ["user_id"],
    )
    op.create_index(
        "ix_refresh_token_jti_user_expires",
        "refresh_token_jti",
        ["user_id", "expires_at"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "refresh_token_jti" not in _table_names(inspector):
        return
    indexes = _index_names(inspector, "refresh_token_jti")
    if "ix_refresh_token_jti_user_expires" in indexes:
        op.drop_index(
            "ix_refresh_token_jti_user_expires", table_name="refresh_token_jti"
        )
    if "ix_refresh_token_jti_user_id" in indexes:
        op.drop_index(
            "ix_refresh_token_jti_user_id", table_name="refresh_token_jti"
        )
    op.drop_table("refresh_token_jti")
