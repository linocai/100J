from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel


class ProjectBase(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None
    start_date: Optional[date] = None
    target_date: Optional[date] = None


class ProjectCreate(ProjectBase):
    space_id: str
    name: str = Field(min_length=1, max_length=255)


class ProjectUpdate(ProjectBase):
    status: Optional[str] = None


class ProjectRead(ORMModel):
    id: str
    user_id: str
    space_id: str
    name: str
    description: Optional[str] = None
    status: str
    start_date: Optional[date] = None
    target_date: Optional[date] = None
    completed_at: Optional[datetime] = None
    archived_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    version: int


class ProjectListResponse(BaseModel):
    items: List[ProjectRead]
    next_cursor: Optional[str] = None

