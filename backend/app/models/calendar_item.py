from datetime import date, datetime

from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import IdMixin, TimestampMixin


class CalendarItem(IdMixin, TimestampMixin, Base):
    __tablename__ = "calendar_items"
    __table_args__ = (
        CheckConstraint(
            "type in ('appointment', 'anniversary', 'subscription_expiry', 'deadline', 'reminder')",
            name="ck_calendar_items_type",
        ),
        CheckConstraint("recurrence in ('none', 'yearly', 'monthly')", name="ck_calendar_items_recurrence"),
        CheckConstraint("source in ('manual', 'agent', 'seed_demo')", name="ck_calendar_items_source"),
        CheckConstraint("length(title) <= 200", name="ck_calendar_title_len"),
        CheckConstraint("description is null or length(description) <= 8000", name="ck_calendar_desc_len"),
        Index("idx_calendar_items_user_space", "user_id", "space_id"),
        Index("idx_calendar_items_start_date", "start_date"),
        Index("idx_calendar_items_start_at", "start_at"),
        Index("idx_calendar_items_type", "type"),
        Index("idx_calendar_items_project_id", "project_id"),
        Index("idx_calendar_items_related_task_id", "related_task_id"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.id"), nullable=False)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=True)
    related_task_id: Mapped[str] = mapped_column(ForeignKey("tasks.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    type: Mapped[str] = mapped_column(String(32), default="appointment", nullable=False)
    all_day: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=True)
    end_date: Mapped[date] = mapped_column(Date, nullable=True)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), default="America/New_York", nullable=False)
    recurrence: Mapped[str] = mapped_column(String(32), default="none", nullable=True)
    remind_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    source: Mapped[str] = mapped_column(String(32), default="manual", nullable=False)

    space = relationship("Space", back_populates="calendar_items")
    project = relationship("Project", back_populates="calendar_items")
    related_task = relationship("Task")
