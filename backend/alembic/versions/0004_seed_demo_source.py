"""allow seed demo source

Revision ID: 0004_seed_demo_source
Revises: 0003_v11_auth_and_limits
Create Date: 2026-05-21
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0004_seed_demo_source"
down_revision: Union[str, None] = "0003_v11_auth_and_limits"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        return
    op.drop_constraint("ck_tasks_source", "tasks", type_="check")
    op.create_check_constraint(
        "ck_tasks_source",
        "tasks",
        "source in ('manual', 'agent', 'seed_demo')",
    )
    op.drop_constraint("ck_calendar_items_source", "calendar_items", type_="check")
    op.create_check_constraint(
        "ck_calendar_items_source",
        "calendar_items",
        "source in ('manual', 'agent', 'seed_demo')",
    )


def downgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        return
    op.drop_constraint("ck_calendar_items_source", "calendar_items", type_="check")
    op.create_check_constraint(
        "ck_calendar_items_source",
        "calendar_items",
        "source in ('manual', 'agent')",
    )
    op.drop_constraint("ck_tasks_source", "tasks", type_="check")
    op.create_check_constraint(
        "ck_tasks_source",
        "tasks",
        "source in ('manual', 'agent')",
    )
