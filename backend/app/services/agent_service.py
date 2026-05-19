import base64
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple

from cryptography.fernet import Fernet
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.models import AgentActionLog, AgentPendingConfirmation, LLMProviderKey
from app.schemas.agent import AgentCommandRequest
from app.schemas.calendar_item import CalendarItemCreate, CalendarItemUpdate
from app.schemas.note import ConvertNoteToTaskRequest, NoteCreate, NoteUpdate
from app.schemas.project import ProjectCreate, ProjectUpdate
from app.schemas.task import TaskCreate, TaskUpdate
from app.services import calendar_service, note_service, project_service, task_service
from app.services.pagination import paginate


TOOLS = [
    {
        "name": "list_tasks",
        "description": "List flexible tasks. Use this for work the user can schedule themselves.",
        "parameters_schema": {},
    },
    {
        "name": "create_task",
        "description": "Create a flexible task. Use this when the user can decide when to do it.",
        "parameters_schema": {},
    },
    {
        "name": "update_task",
        "description": "Update a flexible task.",
        "parameters_schema": {},
    },
    {"name": "complete_task", "description": "Mark a task done.", "parameters_schema": {}},
    {"name": "archive_task", "description": "Archive a task.", "parameters_schema": {}},
    {"name": "list_projects", "description": "List company projects.", "parameters_schema": {}},
    {"name": "create_project", "description": "Create a company project.", "parameters_schema": {}},
    {"name": "update_project", "description": "Update a company project.", "parameters_schema": {}},
    {
        "name": "list_calendar_items",
        "description": "List fixed-time or fixed-date calendar items.",
        "parameters_schema": {},
    },
    {
        "name": "create_calendar_item",
        "description": "Create a fixed-time or fixed-date calendar item.",
        "parameters_schema": {},
    },
    {"name": "update_calendar_item", "description": "Update a calendar item.", "parameters_schema": {}},
    {"name": "list_notes", "description": "List personal notes.", "parameters_schema": {}},
    {"name": "create_note", "description": "Create a personal idea or memo.", "parameters_schema": {}},
    {"name": "update_note", "description": "Update a personal note.", "parameters_schema": {}},
    {
        "name": "convert_note_to_task",
        "description": "Convert a personal note to a personal task while keeping the original note.",
        "parameters_schema": {},
    },
]


def list_tools() -> list:
    return TOOLS


def _fernet() -> Fernet:
    secret = get_settings().llm_key_encryption_secret.encode("utf-8")
    key = base64.urlsafe_b64encode(hashlib.sha256(secret).digest())
    return Fernet(key)


def _preview_api_key(api_key: str) -> str:
    prefix = api_key[:3] if len(api_key) >= 3 else api_key
    suffix = api_key[-4:] if len(api_key) >= 4 else api_key
    return "{}...{}".format(prefix, suffix)


def get_llm_key(db: Session, user_id: str) -> Optional[LLMProviderKey]:
    return db.scalar(
        select(LLMProviderKey).where(
            LLMProviderKey.user_id == user_id,
            LLMProviderKey.is_active.is_(True),
            LLMProviderKey.deleted_at.is_(None),
        )
    )


def upsert_llm_key(db: Session, user_id: str, provider: str, api_key: str) -> LLMProviderKey:
    encrypted = _fernet().encrypt(api_key.encode("utf-8")).decode("utf-8")
    key = get_llm_key(db, user_id)
    if key:
        key.provider = provider
        key.encrypted_api_key = encrypted
        key.key_preview = _preview_api_key(api_key)
        key.is_active = True
        key.version += 1
    else:
        key = LLMProviderKey(
            user_id=user_id,
            provider=provider,
            encrypted_api_key=encrypted,
            key_preview=_preview_api_key(api_key),
            is_active=True,
        )
        db.add(key)
    db.commit()
    db.refresh(key)
    return key


def delete_llm_key(db: Session, user_id: str) -> Optional[LLMProviderKey]:
    key = get_llm_key(db, user_id)
    if not key:
        return None
    key.is_active = False
    db.commit()
    db.refresh(key)
    return key


def log_agent_action(
    db: Session,
    user_id: str,
    action_type: str,
    status: str,
    request_payload: Optional[Dict[str, Any]] = None,
    result_payload: Optional[Dict[str, Any]] = None,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    error_message: Optional[str] = None,
) -> AgentActionLog:
    log = AgentActionLog(
        user_id=user_id,
        action_type=action_type,
        target_type=target_type,
        target_id=target_id,
        request_payload=request_payload,
        result_payload=result_payload,
        status=status,
        error_message=error_message,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


def list_action_logs(db: Session, user_id: str, limit: int = 50, cursor: Optional[str] = None):
    statement = (
        select(AgentActionLog)
        .where(AgentActionLog.user_id == user_id)
        .order_by(AgentActionLog.created_at.desc(), AgentActionLog.id.desc())
    )
    return paginate(db, statement, limit, cursor)


def execute_command(db: Session, user_id: str, request: AgentCommandRequest) -> Dict[str, Any]:
    _validate_agent_arguments(request.command, dict(request.arguments))
    if request.dry_run:
        return {
            "status": "dry_run",
            "would_execute": {"command": request.command, "arguments": request.arguments},
        }

    confirmation_reason = _confirmation_reason(request.command, request.arguments)
    if confirmation_reason:
        token = str(uuid.uuid4())
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=get_settings().pending_confirmation_expire_minutes
        )
        db.add(
            AgentPendingConfirmation(
                token=token,
                user_id=user_id,
                command=request.command,
                arguments=request.arguments,
                expires_at=expires_at,
            )
        )
        db.commit()
        log_agent_action(
            db,
            user_id=user_id,
            action_type=request.command,
            status="requires_confirmation",
            request_payload=request.model_dump(),
            result_payload={"confirmation_token": token, "reason": confirmation_reason},
        )
        return {
            "status": "requires_confirmation",
            "reason": confirmation_reason,
            "confirmation_token": token,
        }

    return _execute_and_log(db, user_id, request.command, request.arguments)


def confirm_command(db: Session, user_id: str, confirmation_token: str) -> Dict[str, Any]:
    pending = db.scalar(
        select(AgentPendingConfirmation).where(
            AgentPendingConfirmation.token == confirmation_token,
            AgentPendingConfirmation.user_id == user_id,
        )
    )
    if not pending:
        raise AppError(status_code=404, code="not_found", message="Confirmation token not found.")

    now = datetime.now(timezone.utc)
    expires_at = pending.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= now:
        db.delete(pending)
        db.commit()
        raise AppError(status_code=404, code="not_found", message="Confirmation token expired.")

    command = pending.command
    arguments = dict(pending.arguments or {})
    db.delete(pending)
    db.commit()
    return _execute_and_log(db, user_id, command, arguments)


def _confirmation_reason(command: str, arguments: Dict[str, Any]) -> Optional[str]:
    if command == "update_calendar_item":
        risky_fields = {"start_at", "end_at", "start_date", "end_date", "all_day"}
        if risky_fields.intersection(arguments.keys()):
            return "This action will modify a calendar item's time."
    if command == "archive_project":
        return "This action will archive an entire project."
    return None


def _validate_agent_arguments(command: str, arguments: Dict[str, Any]) -> None:
    try:
        _validate_agent_arguments_or_raise(command, arguments)
    except (KeyError, ValidationError) as exc:
        raise AppError(status_code=422, code="validation_error", message=str(exc))


def _require_argument(arguments: Dict[str, Any], key: str) -> Any:
    if key not in arguments or arguments[key] in (None, ""):
        raise KeyError("Missing required agent argument: {}".format(key))
    return arguments[key]


def _validate_agent_arguments_or_raise(command: str, arguments: Dict[str, Any]) -> None:
    if command == "list_tasks":
        return
    if command == "create_task":
        TaskCreate(**arguments)
        return
    if command == "update_task":
        _require_argument(arguments, "task_id")
        TaskUpdate(**{key: value for key, value in arguments.items() if key != "task_id"})
        return
    if command in {"complete_task", "archive_task"}:
        _require_argument(arguments, "task_id")
        return
    if command == "list_projects":
        return
    if command == "create_project":
        ProjectCreate(**arguments)
        return
    if command == "update_project":
        _require_argument(arguments, "project_id")
        ProjectUpdate(**{key: value for key, value in arguments.items() if key != "project_id"})
        return
    if command == "archive_project":
        _require_argument(arguments, "project_id")
        return
    if command == "list_calendar_items":
        return
    if command == "create_calendar_item":
        CalendarItemCreate(**arguments)
        return
    if command == "update_calendar_item":
        _require_argument(arguments, "calendar_item_id")
        CalendarItemUpdate(
            **{key: value for key, value in arguments.items() if key != "calendar_item_id"}
        )
        return
    if command == "list_notes":
        return
    if command == "create_note":
        NoteCreate(**arguments)
        return
    if command == "update_note":
        _require_argument(arguments, "note_id")
        NoteUpdate(**{key: value for key, value in arguments.items() if key != "note_id"})
        return
    if command == "convert_note_to_task":
        _require_argument(arguments, "note_id")
        ConvertNoteToTaskRequest(
            **{key: value for key, value in arguments.items() if key != "note_id"}
        )
        return
    raise AppError(status_code=422, code="validation_error", message="Unsupported agent command.")


def _execute_and_log(db: Session, user_id: str, command: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    original_arguments = dict(arguments)
    try:
        result, target_type, target_id = _execute(db, user_id, command, dict(arguments))
        if _is_write_command(command):
            log_agent_action(
                db,
                user_id=user_id,
                action_type=command,
                status="success",
                request_payload={"command": command, "arguments": original_arguments},
                result_payload=result,
                target_type=target_type,
                target_id=target_id,
            )
        return {"status": "success", "result": result}
    except (AppError, ValidationError) as exc:
        if _is_write_command(command):
            log_agent_action(
                db,
                user_id=user_id,
                action_type=command,
                status="failed",
                request_payload={"command": command, "arguments": original_arguments},
                error_message=str(exc),
            )
        if isinstance(exc, AppError):
            raise
        raise AppError(status_code=422, code="validation_error", message=str(exc))


def _is_write_command(command: str) -> bool:
    return command not in {"list_tasks", "list_projects", "list_calendar_items", "list_notes"}


def _execute(
    db: Session,
    user_id: str,
    command: str,
    arguments: Dict[str, Any],
) -> Tuple[Dict[str, Any], Optional[str], Optional[str]]:
    if command == "list_tasks":
        items, next_cursor = task_service.list_tasks(db, user_id, **arguments)
        return {"items": [_compact(item, "task") for item in items], "next_cursor": next_cursor}, None, None
    if command == "create_task":
        task = task_service.create_task(db, user_id, TaskCreate(**arguments), source="agent")
        return {"type": "task", "id": task.id}, "task", task.id
    if command == "update_task":
        task_id = arguments.pop("task_id")
        task = task_service.update_task(db, user_id, task_id, TaskUpdate(**arguments))
        return {"type": "task", "id": task.id}, "task", task.id
    if command == "complete_task":
        task = task_service.set_task_status(db, user_id, arguments["task_id"], "done")
        return {"type": "task", "id": task.id}, "task", task.id
    if command == "archive_task":
        task = task_service.set_task_status(db, user_id, arguments["task_id"], "archived")
        return {"type": "task", "id": task.id}, "task", task.id
    if command == "list_projects":
        items, next_cursor = project_service.list_projects(db, user_id, **arguments)
        return {"items": [_compact(item, "project") for item in items], "next_cursor": next_cursor}, None, None
    if command == "create_project":
        project = project_service.create_project(db, user_id, ProjectCreate(**arguments), source="agent")
        return {"type": "project", "id": project.id}, "project", project.id
    if command == "update_project":
        project_id = arguments.pop("project_id")
        project = project_service.update_project(db, user_id, project_id, ProjectUpdate(**arguments))
        return {"type": "project", "id": project.id}, "project", project.id
    if command == "archive_project":
        project = project_service.set_project_status(db, user_id, arguments["project_id"], "archived")
        return {"type": "project", "id": project.id}, "project", project.id
    if command == "list_calendar_items":
        items, next_cursor = calendar_service.list_calendar_items(db, user_id, **arguments)
        return {"items": [_compact(item, "calendar_item") for item in items], "next_cursor": next_cursor}, None, None
    if command == "create_calendar_item":
        item = calendar_service.create_calendar_item(
            db,
            user_id,
            CalendarItemCreate(**arguments),
            source="agent",
        )
        return {"type": "calendar_item", "id": item.id}, "calendar_item", item.id
    if command == "update_calendar_item":
        calendar_item_id = arguments.pop("calendar_item_id")
        item = calendar_service.update_calendar_item(
            db,
            user_id,
            calendar_item_id,
            CalendarItemUpdate(**arguments),
        )
        return {"type": "calendar_item", "id": item.id}, "calendar_item", item.id
    if command == "list_notes":
        items, next_cursor = note_service.list_notes(db, user_id, **arguments)
        return {"items": [_compact(item, "note") for item in items], "next_cursor": next_cursor}, None, None
    if command == "create_note":
        note = note_service.create_note(db, user_id, NoteCreate(**arguments), source="agent")
        return {"type": "note", "id": note.id}, "note", note.id
    if command == "update_note":
        note_id = arguments.pop("note_id")
        note = note_service.update_note(db, user_id, note_id, NoteUpdate(**arguments))
        return {"type": "note", "id": note.id}, "note", note.id
    if command == "convert_note_to_task":
        note_id = arguments.pop("note_id")
        task, note = note_service.convert_note_to_task(
            db,
            user_id,
            note_id,
            ConvertNoteToTaskRequest(**arguments),
            source="agent",
        )
        return {"type": "task", "id": task.id, "note_id": note.id}, "task", task.id
    raise AppError(status_code=422, code="validation_error", message="Unsupported agent command.")


def _compact(item, item_type: str) -> Dict[str, Any]:
    payload = {"type": item_type, "id": item.id}
    if hasattr(item, "title"):
        payload["title"] = item.title
    if hasattr(item, "name"):
        payload["name"] = item.name
    if hasattr(item, "status"):
        payload["status"] = item.status
    return payload
