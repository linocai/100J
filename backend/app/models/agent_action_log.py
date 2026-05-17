from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import IdMixin, utc_now


class AgentActionLog(IdMixin, Base):
    __tablename__ = "agent_action_logs"
    __table_args__ = (
        CheckConstraint(
            "status in ('success', 'failed', 'requires_confirmation')",
            name="ck_agent_action_logs_status",
        ),
        Index("idx_agent_action_logs_user_id", "user_id"),
        Index("idx_agent_action_logs_created_at", "created_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    action_type: Mapped[str] = mapped_column(String(128), nullable=False)
    target_type: Mapped[str] = mapped_column(String(64), nullable=True)
    target_id: Mapped[str] = mapped_column(String(36), nullable=True)
    request_payload: Mapped[dict] = mapped_column(JSON, nullable=True)
    result_payload: Mapped[dict] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    error_message: Mapped[str] = mapped_column(String(2048), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

