from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models import CalendarItem
from app.schemas.calendar_item import CalendarItemCreate, CalendarItemUpdate
from app.services.pagination import paginate
from app.services.validation_service import (
    get_owned_calendar_item,
    get_owned_space,
    validate_calendar_fields,
    validate_calendar_relations,
    validate_calendar_type,
    validate_recurrence,
)


def list_calendar_items(
    db: Session,
    user_id: str,
    space_id: Optional[str] = None,
    project_id: Optional[str] = None,
    item_type: Optional[str] = None,
    from_date=None,
    to_date=None,
    from_at=None,
    to_at=None,
    limit: int = 50,
    cursor: Optional[str] = None,
):
    from_date = _coerce_date(from_date)
    to_date = _coerce_date(to_date)
    statement = select(CalendarItem).where(
        CalendarItem.user_id == user_id,
        CalendarItem.deleted_at.is_(None),
    )
    if space_id:
        statement = statement.where(CalendarItem.space_id == space_id)
    if project_id:
        statement = statement.where(CalendarItem.project_id == project_id)
    if item_type:
        statement = statement.where(CalendarItem.type == item_type)
    if from_date:
        statement = statement.where(
            or_(
                CalendarItem.start_date >= from_date,
                func.date(CalendarItem.start_at) >= from_date,
            )
        )
    if to_date:
        statement = statement.where(
            or_(
                CalendarItem.start_date <= to_date,
                func.date(CalendarItem.start_at) <= to_date,
            )
        )
    if from_at:
        statement = statement.where(CalendarItem.start_at >= from_at)
    if to_at:
        statement = statement.where(CalendarItem.start_at <= to_at)
    statement = statement.order_by(CalendarItem.start_date.asc(), CalendarItem.start_at.asc(), CalendarItem.id.asc())
    return paginate(db, statement, limit, cursor)


def _coerce_date(value):
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, str):
        return date.fromisoformat(value)
    return value


def create_calendar_item(
    db: Session,
    user_id: str,
    payload: CalendarItemCreate,
    source: str = "manual",
) -> CalendarItem:
    data = payload.model_dump()
    data["type"] = data.get("type") or "appointment"
    data["all_day"] = bool(data.get("all_day"))
    data["timezone"] = data.get("timezone") or "America/New_York"
    data["recurrence"] = data.get("recurrence") or "none"
    _normalize_calendar_all_day_fields(data)
    validate_calendar_type(data["type"])
    validate_recurrence(data["recurrence"])
    validate_calendar_fields(data)
    space = get_owned_space(db, user_id, payload.space_id)
    validate_calendar_relations(db, user_id, space, data.get("project_id"), data.get("related_task_id"))
    item = CalendarItem(user_id=user_id, source=source, **data)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_calendar_item(
    db: Session,
    user_id: str,
    calendar_item_id: str,
    payload: CalendarItemUpdate,
) -> CalendarItem:
    item = get_owned_calendar_item(db, user_id, calendar_item_id)
    data = payload.model_dump(exclude_unset=True)
    merged = {
        "all_day": item.all_day,
        "start_date": item.start_date,
        "end_date": item.end_date,
        "start_at": item.start_at,
        "end_at": item.end_at,
        "project_id": item.project_id,
        "related_task_id": item.related_task_id,
        "type": item.type,
        "recurrence": item.recurrence,
    }
    merged.update(data)
    _normalize_calendar_all_day_fields(merged, mirror_into=data)
    validate_calendar_type(merged["type"])
    validate_recurrence(merged.get("recurrence"))
    validate_calendar_fields(merged)
    space = get_owned_space(db, user_id, item.space_id)
    validate_calendar_relations(
        db,
        user_id,
        space,
        merged.get("project_id"),
        merged.get("related_task_id"),
    )
    for field, value in data.items():
        setattr(item, field, value)
    item.version += 1
    db.commit()
    db.refresh(item)
    return item


def _normalize_calendar_all_day_fields(
    merged: dict,
    mirror_into: Optional[dict] = None,
) -> None:
    """Coerce mutually-exclusive all-day vs timed fields based on ``all_day``.

    Reviewer #4: switching ``all_day`` on a PATCH currently leaves the previous
    half of the fields populated, causing 422s during the otherwise-valid edit
    flow (timed -> all-day or vice versa). Normalising before validation lets
    the request succeed and persists the right shape.

    When ``mirror_into`` is supplied (the update path), the same nulls are
    written back to the caller's mutable ``data`` dict so the subsequent
    ``setattr(item, field, value)`` loop actually clears the columns.
    """

    if merged.get("all_day") is True:
        for field in ("start_at", "end_at"):
            if merged.get(field) is not None:
                merged[field] = None
                if mirror_into is not None:
                    mirror_into[field] = None
    else:
        for field in ("start_date", "end_date"):
            if merged.get(field) is not None:
                merged[field] = None
                if mirror_into is not None:
                    mirror_into[field] = None


def soft_delete_calendar_item(db: Session, user_id: str, calendar_item_id: str) -> CalendarItem:
    item = get_owned_calendar_item(db, user_id, calendar_item_id)
    item.deleted_at = datetime.now(timezone.utc)
    item.version += 1
    db.commit()
    db.refresh(item)
    return item
