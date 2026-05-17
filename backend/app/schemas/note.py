from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel
from app.schemas.task import TaskRead


class NoteBase(BaseModel):
    title: Optional[str] = Field(default=None, max_length=255)
    body: Optional[str] = None
    type: Optional[str] = "idea"


class NoteCreate(NoteBase):
    space_id: str
    body: str = Field(min_length=1)


class NoteUpdate(NoteBase):
    status: Optional[str] = None


class NoteRead(ORMModel):
    id: str
    user_id: str
    space_id: str
    title: Optional[str] = None
    body: str
    type: str
    status: str
    linked_task_id: Optional[str] = None
    source: str
    created_at: datetime
    updated_at: datetime
    version: int


class NoteListResponse(BaseModel):
    items: List[NoteRead]
    next_cursor: Optional[str] = None


class ConvertNoteToTaskRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    priority: str = "medium"
    due_date: Optional[date] = None


class ConvertNoteToTaskResponse(BaseModel):
    task: TaskRead
    note: NoteRead
