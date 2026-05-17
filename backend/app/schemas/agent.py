from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel

from app.schemas.common import ORMModel


class LLMKeyRequest(BaseModel):
    provider: str
    api_key: str


class LLMKeyResponse(BaseModel):
    provider: str
    key_preview: Optional[str] = None
    is_active: bool


class AgentToolRead(BaseModel):
    name: str
    description: str
    parameters_schema: Dict[str, Any]


class AgentToolsResponse(BaseModel):
    tools: List[AgentToolRead]


class AgentCommandRequest(BaseModel):
    command: str
    arguments: Dict[str, Any] = {}
    dry_run: bool = False


class AgentCommandResponse(BaseModel):
    status: str
    result: Optional[Dict[str, Any]] = None
    would_execute: Optional[Dict[str, Any]] = None
    reason: Optional[str] = None
    confirmation_token: Optional[str] = None


class AgentConfirmRequest(BaseModel):
    confirmation_token: str


class AgentActionLogRead(ORMModel):
    id: str
    user_id: str
    action_type: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    request_payload: Optional[Dict[str, Any]] = None
    result_payload: Optional[Dict[str, Any]] = None
    status: str
    error_message: Optional[str] = None
    created_at: datetime


class AgentActionLogListResponse(BaseModel):
    items: List[AgentActionLogRead]
    next_cursor: Optional[str] = None

