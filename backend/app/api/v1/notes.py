from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.common import DeleteResponse
from app.schemas.note import (
    ConvertNoteToTaskRequest,
    ConvertNoteToTaskResponse,
    NoteCreate,
    NoteListResponse,
    NoteRead,
    NoteUpdate,
)
from app.services import note_service
from app.services.validation_service import get_owned_note

router = APIRouter(prefix="/notes", tags=["notes"])


@router.get("", response_model=NoteListResponse)
def list_notes(
    status: Optional[str] = None,
    note_type: Optional[str] = Query(default=None, alias="type"),
    search: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    items, next_cursor = note_service.list_notes(
        db,
        current_user.id,
        status=status,
        note_type=note_type,
        search=search,
        limit=limit,
        cursor=cursor,
    )
    return {"items": items, "next_cursor": next_cursor}


@router.post("", response_model=NoteRead, status_code=201)
def create_note(payload: NoteCreate, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return note_service.create_note(db, current_user.id, payload)


@router.get("/{note_id}", response_model=NoteRead)
def get_note(note_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return get_owned_note(db, current_user.id, note_id)


@router.patch("/{note_id}", response_model=NoteRead)
def update_note(
    note_id: str,
    payload: NoteUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return note_service.update_note(db, current_user.id, note_id, payload)


@router.delete("/{note_id}", response_model=DeleteResponse)
def delete_note(note_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    note = note_service.soft_delete_note(db, current_user.id, note_id)
    return {"id": note.id, "deleted_at": note.deleted_at}


@router.post("/{note_id}/archive", response_model=NoteRead)
def archive_note(note_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return note_service.archive_note(db, current_user.id, note_id)


@router.post("/{note_id}/convert-to-task", response_model=ConvertNoteToTaskResponse)
def convert_note_to_task(
    note_id: str,
    payload: ConvertNoteToTaskRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    task, note = note_service.convert_note_to_task(db, current_user.id, note_id, payload)
    return {"task": task, "note": note}

