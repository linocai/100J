from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.common import DeleteResponse
from app.schemas.task import TaskCreate, TaskListResponse, TaskRead, TaskUpdate
from app.services import task_service

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=TaskListResponse)
def list_tasks(
    space_id: Optional[str] = None,
    project_id: Optional[str] = None,
    project_scope: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    due_before: Optional[date] = None,
    due_after: Optional[date] = None,
    search: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    items, next_cursor = task_service.list_tasks(
        db,
        current_user.id,
        space_id=space_id,
        project_id=project_id,
        project_scope=project_scope,
        status=status,
        priority=priority,
        due_before=due_before,
        due_after=due_after,
        search=search,
        limit=limit,
        cursor=cursor,
    )
    return {"items": items, "next_cursor": next_cursor}


@router.post("", response_model=TaskRead, status_code=201)
def create_task(payload: TaskCreate, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return task_service.create_task(db, current_user.id, payload)


@router.get("/{task_id}", response_model=TaskRead)
def get_task(task_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return task_service.get_owned_task(db, current_user.id, task_id)


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: str,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return task_service.update_task(db, current_user.id, task_id, payload)


@router.delete("/{task_id}", response_model=DeleteResponse)
def delete_task(task_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    task = task_service.soft_delete_task(db, current_user.id, task_id)
    return {"id": task.id, "deleted_at": task.deleted_at}


@router.post("/{task_id}/complete", response_model=TaskRead)
def complete_task(task_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return task_service.set_task_status(db, current_user.id, task_id, "done")


@router.post("/{task_id}/reopen", response_model=TaskRead)
def reopen_task(task_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return task_service.set_task_status(db, current_user.id, task_id, "active")


@router.post("/{task_id}/archive", response_model=TaskRead)
def archive_task(task_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return task_service.set_task_status(db, current_user.id, task_id, "archived")
