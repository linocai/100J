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

from app.core.config import get_settings
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
    """Create or replace the active session for a device_id."""
    now = datetime.now(timezone.utc)
    expires_at = now + _ttl()

    existing = db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )
    plaintext = _generate_token()
    if existing:
        existing.user_id = user.id
        existing.device_name = device_name or existing.device_name
        existing.platform = platform or existing.platform or "macos"
        existing.refresh_token_hash = _hash(plaintext)
        existing.last_seen_at = now
        existing.expires_at = expires_at
        existing.revoked_at = None
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


def rotate(
    db: Session,
    *,
    device_id: str,
    presented_refresh_token: str,
) -> DeviceSessionIssue:
    """Verify a presented refresh token and rotate it."""
    session = db.scalar(
        select(DeviceSession).where(DeviceSession.device_id == device_id)
    )
    if (
        session is None
        or session.revoked_at is not None
        or session.expires_at < datetime.now(timezone.utc)
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

    now = datetime.now(timezone.utc)
    plaintext = _generate_token()
    session.refresh_token_hash = _hash(plaintext)
    session.last_seen_at = now
    session.expires_at = now + _ttl()
    db.commit()
    db.refresh(session)
    return DeviceSessionIssue(user=user, session=session, plaintext_refresh_token=plaintext)


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
