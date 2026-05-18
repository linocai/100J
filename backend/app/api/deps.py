from typing import Optional

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db
from app.core.errors import AppError
from app.core.security import decode_token
from app.models import User
from app.services.auth_service import get_or_create_local_owner


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    settings = get_settings()

    if token:
        payload = decode_token(token, expected_type="access")
        if payload:
            user_id = payload.get("sub")
            user = db.scalar(select(User).where(User.id == user_id, User.deleted_at.is_(None)))
            if user:
                return user
            if settings.auth_mode == "jwt":
                raise AppError(status_code=401, code="unauthorized", message="User not found.")
        elif settings.auth_mode == "jwt":
            raise AppError(status_code=401, code="unauthorized", message="Invalid access token.")

    if settings.auth_mode == "local_owner":
        return get_or_create_local_owner(db)

    raise AppError(status_code=401, code="unauthorized", message="Not authenticated.")
