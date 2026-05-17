from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Note
from app.schemas.note import ConvertNoteToTaskRequest, NoteCreate, NoteUpdate
from app.schemas.task import TaskCreate
from app.services.pagination import paginate
from app.services.task_service import create_task
from app.services.validation_service import (
    get_owned_note,
    get_owned_space,
    validate_note_space,
    validate_note_status,
    validate_note_type,
)


def list_notes(
    db: Session,
    user_id: str,
    status: Optional[str] = None,
    note_type: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 50,
    cursor: Optional[str] = None,
):
    statement = select(Note).where(Note.user_id == user_id, Note.deleted_at.is_(None))
    if status:
        statement = statement.where(Note.status == status)
    if note_type:
        statement = statement.where(Note.type == note_type)
    if search:
        statement = statement.where((Note.title.ilike("%{}%".format(search))) | (Note.body.ilike("%{}%".format(search))))
    statement = statement.order_by(Note.updated_at.desc(), Note.id.desc())
    return paginate(db, statement, limit, cursor)


def create_note(db: Session, user_id: str, payload: NoteCreate, source: str = "manual") -> Note:
    space = get_owned_space(db, user_id, payload.space_id)
    validate_note_space(space)
    validate_note_type(payload.type or "idea")
    note = Note(
        user_id=user_id,
        space_id=payload.space_id,
        title=payload.title,
        body=payload.body,
        type=payload.type or "idea",
        source=source,
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


def update_note(db: Session, user_id: str, note_id: str, payload: NoteUpdate) -> Note:
    note = get_owned_note(db, user_id, note_id)
    data = payload.model_dump(exclude_unset=True)
    if "type" in data and data["type"] is not None:
        validate_note_type(data["type"])
    if "status" in data and data["status"] is not None:
        validate_note_status(data["status"])
    for field, value in data.items():
        setattr(note, field, value)
    note.version += 1
    db.commit()
    db.refresh(note)
    return note


def archive_note(db: Session, user_id: str, note_id: str) -> Note:
    note = get_owned_note(db, user_id, note_id)
    note.status = "archived"
    note.version += 1
    db.commit()
    db.refresh(note)
    return note


def soft_delete_note(db: Session, user_id: str, note_id: str) -> Note:
    note = get_owned_note(db, user_id, note_id)
    note.deleted_at = datetime.now(timezone.utc)
    note.version += 1
    db.commit()
    db.refresh(note)
    return note


def convert_note_to_task(
    db: Session,
    user_id: str,
    note_id: str,
    payload: ConvertNoteToTaskRequest,
    source: str = "manual",
):
    note = get_owned_note(db, user_id, note_id)
    space = get_owned_space(db, user_id, note.space_id)
    validate_note_space(space)
    task_payload = TaskCreate(
        space_id=note.space_id,
        project_id=None,
        title=payload.title,
        description=note.body,
        priority=payload.priority,
        due_date=payload.due_date,
        remind_at=None,
        estimated_minutes=None,
    )
    task = create_task(db, user_id, task_payload, source=source)
    note.linked_task_id = task.id
    note.version += 1
    db.commit()
    db.refresh(note)
    return task, note

