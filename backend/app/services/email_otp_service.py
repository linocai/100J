import secrets
import string
from datetime import datetime, timedelta, timezone
from hashlib import sha256
from typing import Callable

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models import EmailOTPCode, User
from app.services.auth_service import create_default_spaces

OTP_LENGTH = 6
OTP_TTL_MINUTES = 10
OTP_MAX_ATTEMPTS = 5


def _hash(code: str) -> str:
    return sha256(code.encode("utf-8")).hexdigest()


def request_code(db: Session, email: str, send: Callable[[str, str], None]) -> None:
    normalized_email = email.lower()
    code = "".join(secrets.choice(string.digits) for _ in range(OTP_LENGTH))
    db.add(
        EmailOTPCode(
            email=normalized_email,
            code_hash=_hash(code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES),
        )
    )
    db.commit()
    send(normalized_email, code)


def verify_code(db: Session, email: str, code: str) -> User:
    normalized_email = email.lower()
    row = db.scalar(
        select(EmailOTPCode)
        .where(
            EmailOTPCode.email == normalized_email,
            EmailOTPCode.consumed_at.is_(None),
            EmailOTPCode.expires_at > datetime.now(timezone.utc),
        )
        .order_by(EmailOTPCode.created_at.desc())
    )
    if not row:
        raise AppError(401, "unauthorized", "Code expired or not requested.")
    if row.attempts >= OTP_MAX_ATTEMPTS:
        raise AppError(429, "rate_limited", "Too many attempts.")

    row.attempts += 1
    if row.code_hash != _hash(code):
        db.commit()
        raise AppError(401, "unauthorized", "Invalid code.")

    row.consumed_at = datetime.now(timezone.utc)
    user = db.scalar(select(User).where(User.email == normalized_email, User.deleted_at.is_(None)))
    if not user:
        user = User(
            email=normalized_email,
            display_name=normalized_email.split("@", 1)[0],
            password_hash=None,
            timezone="Asia/Shanghai",
            locale="zh-Hans",
        )
        db.add(user)
        db.flush()

    create_default_spaces(db, user)
    db.commit()
    db.refresh(user)
    return user
