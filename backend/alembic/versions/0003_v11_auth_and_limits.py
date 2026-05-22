"""v1.1 auth and limits

Revision ID: 0003_v11_auth_and_limits
Revises: 0002_agent_pending_confirmations
Create Date: 2026-05-21
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "0003_v11_auth_and_limits"
down_revision: Union[str, None] = "0002_agent_pending_confirmations"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name
    inspector = inspect(bind)

    user_columns = _columns(inspector, "users")
    if "apple_user_id" not in user_columns:
        op.add_column("users", sa.Column("apple_user_id", sa.String(length=128), nullable=True))
    if "ix_users_apple_user_id" not in _indexes(inspector, "users"):
        op.create_index(
            "ix_users_apple_user_id",
            "users",
            ["apple_user_id"],
            unique=True,
            postgresql_where=sa.text("apple_user_id IS NOT NULL"),
        )
    if "avatar_url" not in user_columns:
        op.add_column("users", sa.Column("avatar_url", sa.String(length=512), nullable=True))
    if "locale" not in user_columns:
        op.add_column(
            "users",
            sa.Column("locale", sa.String(length=16), server_default="zh-Hans", nullable=False),
        )
    if dialect != "sqlite" and "password_hash" in user_columns:
        op.alter_column(
            "users",
            "password_hash",
            existing_type=sa.String(length=255),
            nullable=True,
        )

    if not inspector.has_table("email_otp_codes"):
        op.create_table(
            "email_otp_codes",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("email", sa.String(length=320), nullable=False),
            sa.Column("code_hash", sa.String(length=255), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
    if "ix_email_otp_codes_email" not in _indexes(inspector, "email_otp_codes"):
        op.create_index("ix_email_otp_codes_email", "email_otp_codes", ["email"])
    if "ix_email_otp_active" not in _indexes(inspector, "email_otp_codes"):
        op.create_index("ix_email_otp_active", "email_otp_codes", ["email", "consumed_at"])

    if not inspector.has_table("device_tokens"):
        op.create_table(
            "device_tokens",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("platform", sa.String(length=16), nullable=False),
            sa.Column("token", sa.String(length=255), nullable=False),
            sa.Column("app_version", sa.String(length=32), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("user_id", "token", name="uq_device_tokens_user_token"),
        )
    if "ix_device_tokens_user_id" not in _indexes(inspector, "device_tokens"):
        op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"])

    if dialect != "sqlite":
        _create_check_if_missing(inspector, "tasks", "ck_tasks_title_len", "length(title) <= 200")
        _create_check_if_missing(
            inspector,
            "tasks",
            "ck_tasks_desc_len",
            "description is null or length(description) <= 8000",
        )
        _create_check_if_missing(
            inspector,
            "notes",
            "ck_notes_title_len",
            "title is null or length(title) <= 200",
        )
        _create_check_if_missing(inspector, "notes", "ck_notes_body_len", "length(body) <= 16000")
        _create_check_if_missing(inspector, "projects", "ck_projects_name_len", "length(name) <= 120")
        _create_check_if_missing(
            inspector,
            "projects",
            "ck_projects_desc_len",
            "description is null or length(description) <= 8000",
        )
        _create_check_if_missing(
            inspector,
            "calendar_items",
            "ck_calendar_title_len",
            "length(title) <= 200",
        )
        _create_check_if_missing(
            inspector,
            "calendar_items",
            "ck_calendar_desc_len",
            "description is null or length(description) <= 8000",
        )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect != "sqlite":
        op.drop_constraint("ck_calendar_desc_len", "calendar_items", type_="check")
        op.drop_constraint("ck_calendar_title_len", "calendar_items", type_="check")
        op.drop_constraint("ck_projects_desc_len", "projects", type_="check")
        op.drop_constraint("ck_projects_name_len", "projects", type_="check")
        op.drop_constraint("ck_notes_body_len", "notes", type_="check")
        op.drop_constraint("ck_notes_title_len", "notes", type_="check")
        op.drop_constraint("ck_tasks_desc_len", "tasks", type_="check")
        op.drop_constraint("ck_tasks_title_len", "tasks", type_="check")

    op.drop_index("ix_device_tokens_user_id", table_name="device_tokens")
    op.drop_table("device_tokens")

    op.drop_index("ix_email_otp_active", table_name="email_otp_codes")
    op.drop_index("ix_email_otp_codes_email", table_name="email_otp_codes")
    op.drop_table("email_otp_codes")

    if dialect != "sqlite":
        op.alter_column(
            "users",
            "password_hash",
            existing_type=sa.String(length=255),
            nullable=False,
        )
    op.drop_column("users", "locale")
    op.drop_column("users", "avatar_url")
    op.drop_index("ix_users_apple_user_id", table_name="users")
    op.drop_column("users", "apple_user_id")


def _columns(inspector, table_name: str) -> set:
    return {column["name"] for column in inspector.get_columns(table_name)}


def _indexes(inspector, table_name: str) -> set:
    if not inspector.has_table(table_name):
        return set()
    return {index["name"] for index in inspector.get_indexes(table_name)}


def _checks(inspector, table_name: str) -> set:
    if not inspector.has_table(table_name):
        return set()
    return {constraint["name"] for constraint in inspector.get_check_constraints(table_name)}


def _create_check_if_missing(inspector, table_name: str, constraint_name: str, condition: str) -> None:
    if constraint_name not in _checks(inspector, table_name):
        op.create_check_constraint(constraint_name, table_name, condition)
