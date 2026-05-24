from typing import Any, Dict, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models import CalendarItem, Note, Project, Space, Task


TASK_STATUSES = {"active", "done", "archived"}
TASK_PRIORITIES = {"low", "medium", "high", "urgent"}
PROJECT_STATUSES = {"active", "completed", "archived"}
CALENDAR_TYPES = {"appointment", "anniversary", "subscription_expiry", "deadline", "reminder"}
RECURRENCES = {"none", "monthly", "yearly"}
NOTE_TYPES = {"idea", "memo"}
NOTE_STATUSES = {"active", "archived"}


def validation_error(message: str, details: Optional[Dict[str, Any]] = None) -> AppError:
    return AppError(status_code=422, code="validation_error", message=message, details=details)


def not_found(message: str) -> AppError:
    return AppError(status_code=404, code="not_found", message=message)


def get_owned_space(db: Session, user_id: str, space_id: str) -> Space:
    space = db.scalar(
        select(Space).where(
            Space.id == space_id,
            Space.user_id == user_id,
            Space.deleted_at.is_(None),
        )
    )
    if not space:
        raise not_found("Space not found.")
    return space


def get_space_by_type(db: Session, user_id: str, space_type: str) -> Space:
    space = db.scalar(
        select(Space).where(
            Space.user_id == user_id,
            Space.type == space_type,
            Space.deleted_at.is_(None),
        )
    )
    if not space:
        raise not_found("Space not found.")
    return space


def get_owned_project(db: Session, user_id: str, project_id: str) -> Project:
    project = db.scalar(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id,
            Project.deleted_at.is_(None),
        )
    )
    if not project:
        raise not_found("Project not found.")
    return project


def get_owned_task(db: Session, user_id: str, task_id: str) -> Task:
    task = db.scalar(
        select(Task).where(Task.id == task_id, Task.user_id == user_id, Task.deleted_at.is_(None))
    )
    if not task:
        raise not_found("Task not found.")
    return task


def get_owned_calendar_item(db: Session, user_id: str, calendar_item_id: str) -> CalendarItem:
    item = db.scalar(
        select(CalendarItem).where(
            CalendarItem.id == calendar_item_id,
            CalendarItem.user_id == user_id,
            CalendarItem.deleted_at.is_(None),
        )
    )
    if not item:
        raise not_found("Calendar item not found.")
    return item


def get_owned_note(db: Session, user_id: str, note_id: str) -> Note:
    note = db.scalar(
        select(Note).where(Note.id == note_id, Note.user_id == user_id, Note.deleted_at.is_(None))
    )
    if not note:
        raise not_found("Note not found.")
    return note


def validate_task_status(status: str) -> None:
    if status not in TASK_STATUSES:
        raise validation_error("Invalid task status.", {"status": status})


def validate_priority(priority: str) -> None:
    if priority not in TASK_PRIORITIES:
        raise validation_error("Invalid task priority.", {"priority": priority})


def validate_project_status(status: str) -> None:
    if status not in PROJECT_STATUSES:
        raise validation_error("Invalid project status.", {"status": status})


def validate_note_status(status: str) -> None:
    if status not in NOTE_STATUSES:
        raise validation_error("Invalid note status.", {"status": status})


def validate_task_project(db: Session, user_id: str, space: Space, project_id: Optional[str]) -> None:
    if space.type == "personal" and project_id:
        raise validation_error("Personal tasks cannot have project_id.", {"project_id": project_id})
    if not project_id:
        return
    project = get_owned_project(db, user_id, project_id)
    if project.space_id != space.id:
        raise validation_error("Task project must belong to the same space.")
    project_space = get_owned_space(db, user_id, project.space_id)
    if project_space.type != "company":
        raise validation_error("Tasks can only be linked to company projects.")


def validate_project_space(space: Space) -> None:
    if space.type != "company":
        raise validation_error("Project can only be created in company space.")


def validate_note_space(space: Space) -> None:
    if space.type != "personal":
        raise validation_error("Note can only belong to personal space.")


def validate_note_type(note_type: str) -> None:
    if note_type not in NOTE_TYPES:
        raise validation_error("Invalid note type.", {"type": note_type})


def validate_calendar_type(item_type: str) -> None:
    if item_type not in CALENDAR_TYPES:
        raise validation_error("Invalid calendar item type.", {"type": item_type})


def validate_recurrence(recurrence: Optional[str]) -> None:
    if recurrence is not None and recurrence not in RECURRENCES:
        raise validation_error("Invalid recurrence.", {"recurrence": recurrence})


def validate_calendar_fields(data: Dict[str, Any]) -> None:
    all_day = bool(data.get("all_day"))
    if all_day:
        if not data.get("start_date"):
            raise validation_error("All-day calendar items require start_date.")
        if data.get("start_at") is not None or data.get("end_at") is not None:
            raise validation_error("All-day calendar items cannot have start_at or end_at.")
        end_date = data.get("end_date")
        if end_date is not None and end_date < data["start_date"]:
            raise validation_error("end_date must be greater than or equal to start_date.")
    else:
        if not data.get("start_at"):
            raise validation_error("Timed calendar items require start_at.")
        if data.get("start_date") is not None:
            raise validation_error("Timed calendar items cannot have start_date.")
        end_at = data.get("end_at")
        if end_at is not None and end_at < data["start_at"]:
            raise validation_error("end_at must be greater than or equal to start_at.")


def validate_calendar_relations(
    db: Session,
    user_id: str,
    space: Space,
    project_id: Optional[str],
    related_task_id: Optional[str],
) -> None:
    if space.type == "personal" and project_id:
        raise validation_error("Personal calendar items cannot have project_id.")
    if project_id:
        project = get_owned_project(db, user_id, project_id)
        if project.space_id != space.id:
            raise validation_error("Calendar item project must belong to the same space.")
    if related_task_id:
        task = get_owned_task(db, user_id, related_task_id)
        if task.space_id != space.id:
            raise validation_error("Related task must belong to the same space.")

