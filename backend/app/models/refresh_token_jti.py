from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import utc_now


class RefreshTokenJTI(Base):
    """v1.2.4 P2-3 (#19) — issued JWT refresh-token jti registry.

    Every JWT refresh token now carries a unique ``jti`` claim. On every
    ``/auth/refresh`` call we look the jti up here:

    * row missing → token was never issued (or already pruned) → 401
    * ``revoked_at IS NOT NULL`` → token already rotated / explicitly revoked → 401
    * ``expires_at <= now()`` → expired → 401

    A successful refresh sets ``revoked_at = now()`` on the presented jti
    and writes a fresh row for the new refresh token. The composite
    ``(user_id, expires_at)`` index supports the lazy cleanup query.

    Device-bound refresh tokens are tracked separately in ``device_sessions``;
    this table is JWT-only (register / login / email-otp / refresh callers).
    """

    __tablename__ = "refresh_token_jti"
    __table_args__ = (
        Index("ix_refresh_token_jti_user_expires", "user_id", "expires_at"),
    )

    jti: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    revoked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
