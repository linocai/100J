from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import IdMixin, utc_now


class DeviceSession(IdMixin, Base):
    """v1.1.2+ — 设备绑定的长期会话。

    用户在任一设备上首次登录（owner-login 或 apple sign in）后创建一行。
    客户端用 device_id 持久化在 UserDefaults，用 refresh_token 安全放在 Keychain。
    之后每次启动只需 `/auth/device-refresh` 静默换 access token，不再要密码 / 访问码。
    """

    __tablename__ = "device_sessions"
    __table_args__ = (
        UniqueConstraint("device_id", name="uq_device_sessions_device_id"),
        Index("ix_device_sessions_user_id", "user_id"),
        Index("ix_device_sessions_active", "device_id", "revoked_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    device_id: Mapped[str] = mapped_column(String(64), nullable=False)
    device_name: Mapped[str] = mapped_column(String(128), nullable=True)
    platform: Mapped[str] = mapped_column(String(16), nullable=False, default="macos")
    refresh_token_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
