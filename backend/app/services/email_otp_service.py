import secrets
import string
from datetime import datetime, timedelta, timezone
from hashlib import sha256
from typing import Callable

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.models import EmailOTPCode, User
from app.services.auth_service import create_default_spaces

OTP_LENGTH = 6
OTP_TTL_MINUTES = 10
OTP_MAX_ATTEMPTS = 5
# P0-4: lazy cleanup probability (1%) — runs inline inside request_code so we
# do not depend on an external cron in v1.2.4. v1.2.5+ will move to a real cron.
CLEANUP_TRIGGER_DENOMINATOR = 100


def _hash(code: str) -> str:
    return sha256(code.encode("utf-8")).hexdigest()


def cleanup_expired(db: Session, older_than_days: int = 7) -> int:
    """Delete OTP rows whose ``expires_at`` is older than ``older_than_days`` days.

    Returns the number of rows deleted. Safe to call frequently; idempotent.
    """

    cutoff = datetime.now(timezone.utc) - timedelta(days=older_than_days)
    result = db.execute(delete(EmailOTPCode).where(EmailOTPCode.expires_at < cutoff))
    db.commit()
    return int(result.rowcount or 0)


def request_code(db: Session, email: str, send: Callable[[str, str], None]) -> None:
    normalized_email = email.lower()

    # Per-email hourly throttle (#16): cap at configured rate before writing a new row.
    settings = get_settings()
    hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    recent_count = db.scalar(
        select(func.count())
        .select_from(EmailOTPCode)
        .where(
            EmailOTPCode.email == normalized_email,
            EmailOTPCode.created_at > hour_ago,
        )
    )
    if (recent_count or 0) >= settings.rate_limit_otp_per_email_per_hour:
        raise AppError(
            status_code=429,
            code="rate_limited",
            message="Too many OTP requests for this email; please wait an hour.",
        )

    code = "".join(secrets.choice(string.digits) for _ in range(OTP_LENGTH))
    db.add(
        EmailOTPCode(
            email=normalized_email,
            code_hash=_hash(code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES),
        )
    )
    db.commit()

    # Lazy cleanup: 1% probability per request. Use secrets (CSPRNG) instead of
    # random.random() — random is not thread-safe under uvicorn workers and is
    # predictable. secrets.randbelow is fine for both concerns.
    if secrets.randbelow(CLEANUP_TRIGGER_DENOMINATOR) == 0:
        try:
            cleanup_expired(db, 7)
        except Exception:  # pragma: no cover — cleanup is best-effort
            db.rollback()

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
