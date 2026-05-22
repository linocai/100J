from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models import CalendarItem, Space, Task

SEED_SOURCE = "seed_demo"


def seed_demo(db: Session, user_id: str) -> dict:
    spaces = list(
        db.scalars(
            select(Space).where(
                Space.user_id == user_id,
                Space.deleted_at.is_(None),
            )
        ).all()
    )
    by_type = {space.type: space for space in spaces}
    personal = by_type.get("personal")
    company = by_type.get("company")
    if not personal or not company:
        raise AppError(
            status_code=409,
            code="missing_spaces",
            message="Default spaces are required before seeding demo data.",
        )

    today = date.today()
    task_specs = [
        {
            "space_id": personal.id,
            "title": "整理今天的 Top 3",
            "description": "从所有事项里挑出三件真正重要的事。",
            "priority": "high",
            "due_date": today,
        },
        {
            "space_id": personal.id,
            "title": "记录一个灵感并转成行动",
            "description": "把一个模糊想法写下来，再判断是否需要变成待办。",
            "priority": "medium",
            "due_date": today + timedelta(days=1),
        },
        {
            "space_id": personal.id,
            "title": "检查订阅和固定提醒",
            "description": "把固定日期事项放入 Calendar，而不是普通待办。",
            "priority": "medium",
            "due_date": today + timedelta(days=2),
        },
        {
            "space_id": company.id,
            "title": "跟进发票和付款状态",
            "description": "公司 loose end 示例：暂时不挂项目。",
            "priority": "high",
            "due_date": today + timedelta(days=1),
        },
        {
            "space_id": company.id,
            "title": "准备本周项目同步",
            "description": "公司待办示例，可稍后挂到具体项目。",
            "priority": "medium",
            "due_date": today + timedelta(days=3),
        },
    ]
    calendar_specs = [
        {
            "space_id": personal.id,
            "title": "个人复盘",
            "description": "固定日程示例：只把有明确时间的事放进 Calendar。",
            "type": "appointment",
            "all_day": True,
            "start_date": today,
            "start_at": None,
            "timezone": "Asia/Shanghai",
            "recurrence": "none",
        },
        {
            "space_id": company.id,
            "title": "公司周会",
            "description": "公司固定日程示例。",
            "type": "appointment",
            "all_day": True,
            "start_date": today + timedelta(days=1),
            "start_at": None,
            "timezone": "Asia/Shanghai",
            "recurrence": "none",
        },
    ]

    created_tasks = 0
    created_calendar_items = 0
    for spec in task_specs:
        if not _task_exists(db, user_id, spec["title"]):
            db.add(Task(user_id=user_id, source=SEED_SOURCE, **spec))
            created_tasks += 1
    for spec in calendar_specs:
        if not _calendar_item_exists(db, user_id, spec["title"]):
            db.add(CalendarItem(user_id=user_id, source=SEED_SOURCE, **spec))
            created_calendar_items += 1

    db.commit()

    tasks = list(
        db.scalars(
            select(Task)
            .where(Task.user_id == user_id, Task.source == SEED_SOURCE, Task.deleted_at.is_(None))
            .order_by(Task.created_at.asc(), Task.id.asc())
        ).all()
    )
    calendar_items = list(
        db.scalars(
            select(CalendarItem)
            .where(
                CalendarItem.user_id == user_id,
                CalendarItem.source == SEED_SOURCE,
                CalendarItem.deleted_at.is_(None),
            )
            .order_by(CalendarItem.created_at.asc(), CalendarItem.id.asc())
        ).all()
    )
    return {
        "tasks": tasks,
        "calendar_items": calendar_items,
        "created": {
            "tasks": created_tasks,
            "calendar_items": created_calendar_items,
        },
    }


def _task_exists(db: Session, user_id: str, title: str) -> bool:
    return (
        db.scalar(
            select(Task.id).where(
                Task.user_id == user_id,
                Task.source == SEED_SOURCE,
                Task.title == title,
                Task.deleted_at.is_(None),
            )
        )
        is not None
    )


def _calendar_item_exists(db: Session, user_id: str, title: str) -> bool:
    return (
        db.scalar(
            select(CalendarItem.id).where(
                CalendarItem.user_id == user_id,
                CalendarItem.source == SEED_SOURCE,
                CalendarItem.title == title,
                CalendarItem.deleted_at.is_(None),
            )
        )
        is not None
    )
