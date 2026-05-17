from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Project
from app.schemas.project import ProjectCreate, ProjectUpdate
from app.schemas.task import ProjectTaskCreate, TaskCreate
from app.services.pagination import paginate
from app.services.task_service import create_task
from app.services.validation_service import (
    get_owned_project,
    get_owned_space,
    validate_project_space,
    validate_project_status,
)


def list_projects(
    db: Session,
    user_id: str,
    space_id: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 50,
    cursor: Optional[str] = None,
):
    statement = select(Project).where(Project.user_id == user_id, Project.deleted_at.is_(None))
    if space_id:
        statement = statement.where(Project.space_id == space_id)
    if status:
        statement = statement.where(Project.status == status)
    if search:
        statement = statement.where(Project.name.ilike("%{}%".format(search)))
    statement = statement.order_by(Project.updated_at.desc(), Project.id.desc())
    return paginate(db, statement, limit, cursor)


def create_project(db: Session, user_id: str, payload: ProjectCreate, source: str = "manual") -> Project:
    del source
    space = get_owned_space(db, user_id, payload.space_id)
    validate_project_space(space)
    project = Project(
        user_id=user_id,
        space_id=payload.space_id,
        name=payload.name,
        description=payload.description,
        start_date=payload.start_date,
        target_date=payload.target_date,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def update_project(db: Session, user_id: str, project_id: str, payload: ProjectUpdate) -> Project:
    project = get_owned_project(db, user_id, project_id)
    data = payload.model_dump(exclude_unset=True)
    if "status" in data and data["status"] is not None:
        validate_project_status(data["status"])
    for field, value in data.items():
        setattr(project, field, value)
    if "status" in data:
        apply_project_status_timestamps(project)
    project.version += 1
    db.commit()
    db.refresh(project)
    return project


def apply_project_status_timestamps(project: Project) -> None:
    now = datetime.now(timezone.utc)
    if project.status == "completed":
        project.completed_at = project.completed_at or now
        project.archived_at = None
    elif project.status == "archived":
        project.archived_at = project.archived_at or now
        project.completed_at = None
    else:
        project.completed_at = None
        project.archived_at = None


def set_project_status(db: Session, user_id: str, project_id: str, status: str) -> Project:
    validate_project_status(status)
    project = get_owned_project(db, user_id, project_id)
    project.status = status
    apply_project_status_timestamps(project)
    project.version += 1
    db.commit()
    db.refresh(project)
    return project


def soft_delete_project(db: Session, user_id: str, project_id: str) -> Project:
    project = get_owned_project(db, user_id, project_id)
    project.deleted_at = datetime.now(timezone.utc)
    project.version += 1
    db.commit()
    db.refresh(project)
    return project


def create_project_task(
    db: Session,
    user_id: str,
    project_id: str,
    payload: ProjectTaskCreate,
    source: str = "manual",
):
    project = get_owned_project(db, user_id, project_id)
    task_payload = TaskCreate(
        space_id=project.space_id,
        project_id=project.id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority or "medium",
        due_date=payload.due_date,
        remind_at=payload.remind_at,
        estimated_minutes=payload.estimated_minutes,
    )
    return create_task(db, user_id, task_payload, source=source)

