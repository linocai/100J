from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel
from app.schemas.limits import LONG_TEXT_MAX_LENGTH, SHORT_TEXT_MAX_LENGTH


class TaskBase(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=SHORT_TEXT_MAX_LENGTH)
    description: Optional[str] = Field(default=None, max_length=LONG_TEXT_MAX_LENGTH)
    priority: Optional[str] = "medium"
    due_date: Optional[date] = None
    remind_at: Optional[datetime] = None
    estimated_minutes: Optional[int] = None


class TaskCreate(TaskBase):
    space_id: str
    project_id: Optional[str] = None
    title: str = Field(min_length=1, max_length=SHORT_TEXT_MAX_LENGTH)


class ProjectTaskCreate(TaskBase):
    title: str = Field(min_length=1, max_length=SHORT_TEXT_MAX_LENGTH)


class TaskUpdate(TaskBase):
    project_id: Optional[str] = None
    status: Optional[str] = None


class TaskRead(ORMModel):
    id: str
    user_id: str
    space_id: str
    project_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    status: str
    priority: str
    due_date: Optional[date] = None
    remind_at: Optional[datetime] = None
    estimated_minutes: Optional[int] = None
    source: str
    completed_at: Optional[datetime] = None
    archived_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    version: int


class TaskListResponse(BaseModel):
    items: List[TaskRead]
    next_cursor: Optional[str] = None
