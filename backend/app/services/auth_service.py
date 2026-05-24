import secrets
from datetime import datetime, timedelta, timezone
from secrets import compare_digest

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import create_access_token, create_refresh_token, hash_password, verify_password
from app.models import RefreshTokenJTI, Space, User

# P2-3: lazy cleanup probability (1%) — runs inline inside issue_tokens so we
# don't rely on an external cron in v1.2.4. Mirrors email_otp_service's
# CLEANUP_TRIGGER_DENOMINATOR pattern.
JTI_CLEANUP_TRIGGER_DENOMINATOR = 100


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
    if not user or not user.password_hash or not verify_password(password, user.password_hash):
        raise AppError(status_code=401, code="unauthorized", message="Invalid email or password.")
    return user


def authenticate_owner_access_code(db: Session, access_code: str) -> User:
    settings = get_settings()
    expected_code = settings.owner_cloud_access_code.strip()
    if not expected_code:
        raise AppError(
            status_code=503,
            code="owner_access_code_not_configured",
            message="Owner cloud access code is not configured.",
        )
    if not compare_digest(access_code, expected_code):
        raise AppError(status_code=401, code="unauthorized", message="Invalid cloud access code.")
    return get_or_create_local_owner(db)


def get_or_create_local_owner(db: Session) -> User:
    settings = get_settings()
    email = settings.local_owner_email.lower()
    user = db.scalar(select(User).where(User.email == email, User.deleted_at.is_(None)))
    if not user:
        user = User(
            email=email,
            password_hash=hash_password("local-owner-password-not-used"),
            display_name=settings.local_owner_display_name,
            timezone=settings.local_owner_timezone,
        )
        db.add(user)
        db.flush()
    else:
        changed = False
        if user.display_name != settings.local_owner_display_name:
            user.display_name = settings.local_owner_display_name
            changed = True
        if user.timezone != settings.local_owner_timezone:
            user.timezone = settings.local_owner_timezone
            changed = True
        if changed:
            user.version += 1

    create_default_spaces(db, user)
    db.commit()
    db.refresh(user)
    return user


def cleanup_expired_jti(db: Session, older_than_days: int = 1) -> int:
    """P2-3 (#19): drop ``refresh_token_jti`` rows whose ``expires_at`` is
    older than ``older_than_days`` days.

    Returns the number of rows deleted. Best-effort; callers should swallow
    exceptions because this runs inline on the request path.
    """

    cutoff = datetime.now(timezone.utc) - timedelta(days=older_than_days)
    result = db.execute(
        delete(RefreshTokenJTI).where(RefreshTokenJTI.expires_at < cutoff)
    )
    db.commit()
    return int(result.rowcount or 0)


def issue_tokens(user: User, db: Session) -> dict:
    """v1.2.4 P2-3 (#19): each call now persists the refresh-token jti so
    /auth/refresh can rotate-and-blacklist instead of replaying the same
    token forever.

    ``db`` is required so we can write the jti row. All known callers
    already have a Session in scope; passing it explicitly keeps the
    function dependency-free of FastAPI request state.
    """
    settings = get_settings()
    refresh_token, jti = create_refresh_token(user.id)
    now = datetime.now(timezone.utc)
    db.add(
        RefreshTokenJTI(
            jti=jti,
            user_id=user.id,
            issued_at=now,
            expires_at=now + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    db.commit()

    # Lazy cleanup — same pattern as email_otp_service.request_code.
    if secrets.randbelow(JTI_CLEANUP_TRIGGER_DENOMINATOR) == 0:
        try:
            cleanup_expired_jti(db)
        except Exception:  # pragma: no cover — best-effort
            db.rollback()

    return {
        "access_token": create_access_token(user.id),
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }
