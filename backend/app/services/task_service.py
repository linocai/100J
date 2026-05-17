from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Task
from app.schemas.task import TaskCreate, TaskUpdate
from app.services.pagination import paginate
from app.services.validation_service import (
    get_owned_space,
    get_owned_task,
    validate_priority,
    validate_task_project,
    validate_task_status,
)


def list_tasks(
    db: Session,
    user_id: str,
    space_id: Optional[str] = None,
    project_id: Optional[str] = None,
    project_scope: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    due_before=None,
    due_after=None,
    search: Optional[str] = None,
    limit: int = 50,
    cursor: Optional[str] = None,
):
    statement = select(Task).where(Task.user_id == user_id, Task.deleted_at.is_(None))
    if space_id:
        statement = statement.where(Task.space_id == space_id)
    if project_id:
        statement = statement.where(Task.project_id == project_id)
    if project_scope == "no_project":
        statement = statement.where(Task.project_id.is_(None))
    elif project_scope == "with_project":
        statement = statement.where(Task.project_id.is_not(None))
    if status:
        statement = statement.where(Task.status == status)
    if priority:
        statement = statement.where(Task.priority == priority)
    if due_before:
        statement = statement.where(Task.due_date <= due_before)
    if due_after:
        statement = statement.where(Task.due_date >= due_after)
    if search:
        statement = statement.where(Task.title.ilike("%{}%".format(search)))
    statement = statement.order_by(Task.updated_at.desc(), Task.id.desc())
    return paginate(db, statement, limit, cursor)


def create_task(db: Session, user_id: str, payload: TaskCreate, source: str = "manual") -> Task:
    space = get_owned_space(db, user_id, payload.space_id)
    validate_priority(payload.priority or "medium")
    validate_task_project(db, user_id, space, payload.project_id)
    task = Task(
        user_id=user_id,
        space_id=payload.space_id,
        project_id=payload.project_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority or "medium",
        due_date=payload.due_date,
        remind_at=payload.remind_at,
        estimated_minutes=payload.estimated_minutes,
        source=source,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def update_task(db: Session, user_id: str, task_id: str, payload: TaskUpdate) -> Task:
    task = get_owned_task(db, user_id, task_id)
    data = payload.model_dump(exclude_unset=True)
    if "priority" in data and data["priority"] is not None:
        validate_priority(data["priority"])
    if "status" in data and data["status"] is not None:
        validate_task_status(data["status"])
    if "project_id" in data:
        space = get_owned_space(db, user_id, task.space_id)
        validate_task_project(db, user_id, space, data["project_id"])

    for field, value in data.items():
        setattr(task, field, value)
    if "status" in data:
        apply_task_status_timestamps(task)
    task.version += 1
    db.commit()
    db.refresh(task)
    return task


def apply_task_status_timestamps(task: Task) -> None:
    now = datetime.now(timezone.utc)
    if task.status == "done":
        task.completed_at = task.completed_at or now
        task.archived_at = None
    elif task.status == "archived":
        task.archived_at = task.archived_at or now
        task.completed_at = None
    else:
        task.completed_at = None
        task.archived_at = None


def set_task_status(db: Session, user_id: str, task_id: str, status: str) -> Task:
    validate_task_status(status)
    task = get_owned_task(db, user_id, task_id)
    task.status = status
    apply_task_status_timestamps(task)
    task.version += 1
    db.commit()
    db.refresh(task)
    return task


def soft_delete_task(db: Session, user_id: str, task_id: str) -> Task:
    task = get_owned_task(db, user_id, task_id)
    task.deleted_at = datetime.now(timezone.utc)
    task.version += 1
    db.commit()
    db.refresh(task)
    return task

