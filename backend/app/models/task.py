from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import IdMixin, TimestampMixin


class Task(IdMixin, TimestampMixin, Base):
    __tablename__ = "tasks"
    __table_args__ = (
        CheckConstraint("status in ('active', 'done', 'archived')", name="ck_tasks_status"),
        CheckConstraint("priority in ('low', 'medium', 'high', 'urgent')", name="ck_tasks_priority"),
        CheckConstraint("source in ('manual', 'agent', 'seed_demo')", name="ck_tasks_source"),
        CheckConstraint("length(title) <= 200", name="ck_tasks_title_len"),
        CheckConstraint("description is null or length(description) <= 8000", name="ck_tasks_desc_len"),
        Index("idx_tasks_user_space", "user_id", "space_id"),
        Index("idx_tasks_project_id", "project_id"),
        Index("idx_tasks_status", "status"),
        Index("idx_tasks_due_date", "due_date"),
        Index("idx_tasks_updated_at", "updated_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.id"), nullable=False)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
    priority: Mapped[str] = mapped_column(String(32), default="medium", nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=True)
    remind_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    estimated_minutes: Mapped[int] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String(32), default="manual", nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)

    space = relationship("Space", back_populates="tasks")
    project = relationship("Project", back_populates="tasks")
