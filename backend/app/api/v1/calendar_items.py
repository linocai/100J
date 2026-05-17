from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.calendar_item import (
    CalendarItemCreate,
    CalendarItemListResponse,
    CalendarItemRead,
    CalendarItemUpdate,
)
from app.schemas.common import DeleteResponse
from app.services import calendar_service
from app.services.validation_service import get_owned_calendar_item

router = APIRouter(prefix="/calendar-items", tags=["calendar-items"])


@router.get("", response_model=CalendarItemListResponse)
def list_calendar_items(
    space_id: Optional[str] = None,
    project_id: Optional[str] = None,
    item_type: Optional[str] = Query(default=None, alias="type"),
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    from_at: Optional[datetime] = None,
    to_at: Optional[datetime] = None,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    items, next_cursor = calendar_service.list_calendar_items(
        db,
        current_user.id,
        space_id=space_id,
        project_id=project_id,
        item_type=item_type,
        from_date=from_date,
        to_date=to_date,
        from_at=from_at,
        to_at=to_at,
        limit=limit,
        cursor=cursor,
    )
    return {"items": items, "next_cursor": next_cursor}


@router.post("", response_model=CalendarItemRead, status_code=201)
def create_calendar_item(
    payload: CalendarItemCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return calendar_service.create_calendar_item(db, current_user.id, payload)


@router.get("/{calendar_item_id}", response_model=CalendarItemRead)
def get_calendar_item(
    calendar_item_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return get_owned_calendar_item(db, current_user.id, calendar_item_id)


@router.patch("/{calendar_item_id}", response_model=CalendarItemRead)
def update_calendar_item(
    calendar_item_id: str,
    payload: CalendarItemUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return calendar_service.update_calendar_item(db, current_user.id, calendar_item_id, payload)


@router.delete("/{calendar_item_id}", response_model=DeleteResponse)
def delete_calendar_item(
    calendar_item_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    item = calendar_service.soft_delete_calendar_item(db, current_user.id, calendar_item_id)
    return {"id": item.id, "deleted_at": item.deleted_at}

