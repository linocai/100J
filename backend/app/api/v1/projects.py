from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.common import DeleteResponse
from app.schemas.project import ProjectCreate, ProjectListResponse, ProjectRead, ProjectUpdate
from app.schemas.task import ProjectTaskCreate, TaskListResponse, TaskRead
from app.services import project_service, task_service
from app.services.validation_service import get_owned_project

router = APIRouter(prefix="/projects", tags=["projects"])


@router.get("", response_model=ProjectListResponse)
def list_projects(
    space_id: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    items, next_cursor = project_service.list_projects(
        db,
        current_user.id,
        space_id=space_id,
        status=status,
        search=search,
        limit=limit,
        cursor=cursor,
    )
    return {"items": items, "next_cursor": next_cursor}


@router.post("", response_model=ProjectRead, status_code=201)
def create_project(payload: ProjectCreate, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return project_service.create_project(db, current_user.id, payload)


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(project_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return get_owned_project(db, current_user.id, project_id)


@router.patch("/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return project_service.update_project(db, current_user.id, project_id, payload)


@router.delete("/{project_id}", response_model=DeleteResponse)
def delete_project(project_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    project = project_service.soft_delete_project(db, current_user.id, project_id)
    return {"id": project.id, "deleted_at": project.deleted_at}


@router.post("/{project_id}/archive", response_model=ProjectRead)
def archive_project(project_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return project_service.set_project_status(db, current_user.id, project_id, "archived")


@router.post("/{project_id}/complete", response_model=ProjectRead)
def complete_project(project_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return project_service.set_project_status(db, current_user.id, project_id, "completed")


@router.get("/{project_id}/tasks", response_model=TaskListResponse)
def list_project_tasks(
    project_id: str,
    status: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    get_owned_project(db, current_user.id, project_id)
    items, next_cursor = task_service.list_tasks(
        db,
        current_user.id,
        project_id=project_id,
        status=status,
        limit=limit,
        cursor=cursor,
    )
    return {"items": items, "next_cursor": next_cursor}


@router.post("/{project_id}/tasks", response_model=TaskRead, status_code=201)
def create_project_task(
    project_id: str,
    payload: ProjectTaskCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return project_service.create_project_task(db, current_user.id, project_id, payload)

