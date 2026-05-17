from typing import List, Optional

from pydantic import BaseModel

from app.schemas.common import ORMModel


class SpaceRead(ORMModel):
    id: str
    name: str
    type: str


class SpaceListResponse(BaseModel):
    items: List[SpaceRead]
    next_cursor: Optional[str] = None

