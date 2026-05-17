from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import create_access_token, create_refresh_token, hash_password, verify_password
from app.models import Space, User


def create_default_spaces(db: Session, user: User) -> None:
    existing = list(
        db.scalars(select(Space).where(Space.user_id == user.id, Space.deleted_at.is_(None))).all()
    )
    existing_types = {space.type for space in existing}
    if "personal" not in existing_types:
        db.add(Space(user_id=user.id, name="Personal", type="personal"))
    if "company" not in existing_types:
        db.add(Space(user_id=user.id, name="Company", type="company"))


def register_user(db: Session, email: str, password: str, display_name: str, timezone: str) -> User:
    normalized_email = email.lower()
    existing = db.scalar(select(User).where(User.email == normalized_email, User.deleted_at.is_(None)))
    if existing:
        raise AppError(status_code=409, code="conflict", message="Email already registered.")
    user = User(
        email=normalized_email,
        password_hash=hash_password(password),
        display_name=display_name,
        timezone=timezone,
    )
    db.add(user)
    db.flush()
    create_default_spaces(db, user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == email.lower(), User.deleted_at.is_(None)))
    if not user or not verify_password(password, user.password_hash):
        raise AppError(status_code=401, code="unauthorized", message="Invalid email or password.")
    return user


def issue_tokens(user: User) -> dict:
    return {
        "access_token": create_access_token(user.id),
        "refresh_token": create_refresh_token(user.id),
        "token_type": "bearer",
    }

