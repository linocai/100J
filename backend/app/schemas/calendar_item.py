from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel
from app.schemas.limits import LONG_TEXT_MAX_LENGTH, SHORT_TEXT_MAX_LENGTH


class CalendarItemBase(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=SHORT_TEXT_MAX_LENGTH)
    description: Optional[str] = Field(default=None, max_length=LONG_TEXT_MAX_LENGTH)
    type: Optional[str] = "appointment"
    all_day: Optional[bool] = False
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    timezone: Optional[str] = "America/New_York"
    recurrence: Optional[str] = "none"
    remind_at: Optional[datetime] = None
    project_id: Optional[str] = None
    related_task_id: Optional[str] = None


class CalendarItemCreate(CalendarItemBase):
    space_id: str
    title: str = Field(min_length=1, max_length=SHORT_TEXT_MAX_LENGTH)


class CalendarItemUpdate(CalendarItemBase):
    pass


class CalendarItemRead(ORMModel):
    id: str
    user_id: str
    space_id: str
    project_id: Optional[str] = None
    related_task_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    type: str
    all_day: bool
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    timezone: str
    recurrence: Optional[str] = None
    remind_at: Optional[datetime] = None
    source: str
    created_at: datetime
    updated_at: datetime
    version: int


class CalendarItemListResponse(BaseModel):
    items: List[CalendarItemRead]
    next_cursor: Optional[str] = None
