from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import IdMixin, TimestampMixin


class Note(IdMixin, TimestampMixin, Base):
    __tablename__ = "notes"
    __table_args__ = (
        CheckConstraint("type in ('idea', 'memo')", name="ck_notes_type"),
        CheckConstraint("status in ('active', 'archived')", name="ck_notes_status"),
        CheckConstraint("source in ('manual', 'agent')", name="ck_notes_source"),
        Index("idx_notes_user_space", "user_id", "space_id"),
        Index("idx_notes_status", "status"),
        Index("idx_notes_updated_at", "updated_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[str] = mapped_column(String(32), default="idea", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
    linked_task_id: Mapped[str] = mapped_column(ForeignKey("tasks.id"), nullable=True)
    source: Mapped[str] = mapped_column(String(32), default="manual", nullable=False)

    space = relationship("Space", back_populates="notes")
    linked_task = relationship("Task")

