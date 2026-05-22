from typing import Dict, List

from pydantic import BaseModel

from app.schemas.calendar_item import CalendarItemRead
from app.schemas.task import TaskRead


class SeedDemoResponse(BaseModel):
    tasks: List[TaskRead]
    calendar_items: List[CalendarItemRead]
    created: Dict[str, int]
