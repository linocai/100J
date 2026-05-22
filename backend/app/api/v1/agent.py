from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.schemas.agent import (
    AgentActionLogListResponse,
    AgentCommandRequest,
    AgentCommandResponse,
    AgentConfirmRequest,
    AgentToolsResponse,
    LLMKeyRequest,
    LLMKeyResponse,
)
from app.services import agent_service

router = APIRouter(prefix="/agent", tags=["agent"])


@router.get("/llm-key", response_model=LLMKeyResponse)
def get_llm_key(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    key = agent_service.get_llm_key(db, current_user.id)
    if not key:
        return {"provider": "", "key_preview": None, "is_active": False}
    return {"provider": key.provider, "key_preview": key.key_preview, "is_active": key.is_active}


@router.put("/llm-key", response_model=LLMKeyResponse)
def put_llm_key(
    payload: LLMKeyRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    key = agent_service.upsert_llm_key(db, current_user.id, payload.provider, payload.api_key)
    return {"provider": key.provider, "key_preview": key.key_preview, "is_active": key.is_active}


@router.delete("/llm-key")
def delete_llm_key(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    agent_service.delete_llm_key(db, current_user.id)
    return {"status": "ok"}


@router.get("/tools", response_model=AgentToolsResponse)
def get_tools():
    return {"tools": agent_service.list_tools()}


@router.post("/commands", response_model=AgentCommandResponse)
@limiter.limit("30/minute")
def execute_command(
    request: Request,
    payload: AgentCommandRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return agent_service.execute_command(db, current_user.id, payload)


@router.post("/commands/confirm", response_model=AgentCommandResponse)
@limiter.limit("30/minute")
def confirm_command(
    request: Request,
    payload: AgentConfirmRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return agent_service.confirm_command(db, current_user.id, payload.confirmation_token)


@router.get("/action-logs", response_model=AgentActionLogListResponse)
def list_action_logs(
    limit: int = Query(50, ge=1, le=100),
    cursor: str = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    items, next_cursor = agent_service.list_action_logs(db, current_user.id, limit, cursor)
    return {"items": items, "next_cursor": next_cursor}
