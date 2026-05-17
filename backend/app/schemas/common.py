from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class PageMeta(BaseModel):
    next_cursor: Optional[str] = None


class ErrorEnvelope(BaseModel):
    error: Dict[str, Any]


class DeleteResponse(BaseModel):
    id: str
    deleted_at: datetime


class ItemsResponse(BaseModel):
    items: List[Any]
    next_cursor: Optional[str] = None

