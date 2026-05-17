from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models import Space, User
from app.schemas.space import SpaceListResponse, SpaceRead
from app.services.validation_service import get_owned_space

router = APIRouter(prefix="/spaces", tags=["spaces"])


@router.get("", response_model=SpaceListResponse)
def list_spaces(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    spaces = list(
        db.scalars(
            select(Space).where(Space.user_id == current_user.id, Space.deleted_at.is_(None)).order_by(Space.type)
        ).all()
    )
    return {"items": spaces, "next_cursor": None}


@router.get("/{space_id}", response_model=SpaceRead)
def get_space(space_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return get_owned_space(db, current_user.id, space_id)

