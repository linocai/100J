"""Device-bound long-lived sessions.

Issued at first login on a device, refreshed silently by the client on every
launch so the user never sees the access code again.

- `device_id` is supplied by the client (UUID, persisted in UserDefaults).
- `refresh_token` is a high-entropy opaque string returned only once at
  issue / rotate; only its SHA-256 hash is stored.
- Access tokens stay JWT (short-lived) so existing middleware works.
"""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import create_access_token
from app.models import DeviceSession, User

DEFAULT_TTL_DAYS = 365


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _generate_token() -> str:
    # 256 bits of entropy; URL-safe.
    return secrets.token_urlsafe(48)


@dataclass
class DeviceSessionIssue:
    user: User
    session: DeviceSession
    plaintext_refresh_token: str  # only available right after issue/rotate

    def to_response(self) -> dict:
        return {
            "access_token": create_access_token(self.user.id),
            "refresh_token": self.plaintext_refresh_token,
            "token_type": "bearer",
            "device_id": self.session.device_id,
            "device_name": self.session.device_name,
            "expires_at": self.session.expires_at.isoformat(),
        }


def _ttl() -> timedelta:
    return timedelta(days=DEFAULT_TTL_DAYS)


def issue(
    db: Session,
    *,
    user: User,
    device_id: str,
    device_name: Optional[str],
    platform: str,
) -> DeviceSessionIssue:
    """Create or replace the active session for a device_id.

    v1.2.4 (#25): when an existing row was previously revoked we MUST NOT
    silently un-revoke it — that would let a leaked device_id resurrect a
    session the user already killed. Instead we hard-delete the dead row
    and insert a fresh one so audit trails (created_at) stay honest.
    """
    now = datetime.now(timezone.utc)
    expires_at = now + _ttl()

    existing = db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )
    plaintext = _generate_token()
    if existing is not None and existing.revoked_at is not None:
        # Treat revoked row as if it doesn't exist: delete it and fall
        # through to the "create new row" branch below.
        db.delete(existing)
        db.flush()
        existing = None

    if existing:
        # Safety net: this branch only runs for live rows now.
        assert existing.revoked_at is None
        existing.user_id = user.id
        existing.device_name = device_name or existing.device_name
        existing.platform = platform or existing.platform or "macos"
        existing.refresh_token_hash = _hash(plaintext)
        existing.last_seen_at = now
        existing.expires_at = expires_at
        session = existing
    else:
        session = DeviceSession(
            user_id=user.id,
            device_id=device_id,
            device_name=device_name,
            platform=platform or "macos",
            refresh_token_hash=_hash(plaintext),
            last_seen_at=now,
            expires_at=expires_at,
        )
        db.add(session)
    db.commit()
    db.refresh(session)
    return DeviceSessionIssue(user=user, session=session, plaintext_refresh_token=plaintext)


def _as_aware_utc(value: datetime) -> datetime:
    """SQLite (test env) hands datetimes back as naive; Postgres keeps tz info.

    Normalize so comparisons with `datetime.now(timezone.utc)` never raise
    `can't compare offset-naive and offset-aware datetimes`.
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _verify_token_or_raise(
    db: Session,
    *,
    device_id: str,
    presented_refresh_token: str,
) -> tuple[DeviceSession, User]:
    """Shared check used by both rotate() and verify().

    Returns (session, user) on success. Raises AppError(401) otherwise.
    """
    session = db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )
    if (
        session is None
        or session.revoked_at is not None
        or _as_aware_utc(session.expires_at) < datetime.now(timezone.utc)
        or session.refresh_token_hash != _hash(presented_refresh_token)
    ):
        raise AppError(
            status_code=401,
            code="unauthorized",
            message="Device session expired. Please sign in again.",
        )

    user = db.scalar(
        select(User).where(User.id == session.user_id, User.deleted_at.is_(None))
    )
    if user is None:
        raise AppError(
            status_code=401,
            code="unauthorized",
            message="User no longer exists.",
        )
    return session, user


def rotate(
    db: Session,
    *,
    device_id: str,
    presented_refresh_token: str,
) -> DeviceSessionIssue:
    """Verify a presented refresh token and rotate it."""
    session, user = _verify_token_or_raise(
        db,
        device_id=device_id,
        presented_refresh_token=presented_refresh_token,
    )

    now = datetime.now(timezone.utc)
    plaintext = _generate_token()
    session.refresh_token_hash = _hash(plaintext)
    session.last_seen_at = now
    session.expires_at = now + _ttl()
    db.commit()
    db.refresh(session)
    return DeviceSessionIssue(user=user, session=session, plaintext_refresh_token=plaintext)


def verify(
    db: Session,
    *,
    device_id: str,
    presented_refresh_token: str,
) -> DeviceSession:
    """v1.2.4: validate a refresh token WITHOUT rotating it.

    Used by /auth/device-logout to authenticate the caller before revoking.
    The token stays valid; revoke() is the next call.
    """
    session, _user = _verify_token_or_raise(
        db,
        device_id=device_id,
        presented_refresh_token=presented_refresh_token,
    )
    return session


def get(db: Session, *, device_id: str) -> Optional[DeviceSession]:
    """Fetch a device session by id without any validity checks."""
    return db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )


def revoke(db: Session, *, device_id: str) -> None:
    session = db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )
    if session is None or session.revoked_at is not None:
        return
    session.revoked_at = datetime.now(timezone.utc)
    db.commit()


def list_for_user(db: Session, user_id: str) -> list[DeviceSession]:
    return list(
        db.scalars(
            select(DeviceSession)
            .where(DeviceSession.user_id == user_id, DeviceSession.revoked_at.is_(None))
            .order_by(DeviceSession.last_seen_at.desc())
        )
    )
