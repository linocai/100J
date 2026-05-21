from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import IdMixin, TimestampMixin


class Project(IdMixin, TimestampMixin, Base):
    __tablename__ = "projects"
    __table_args__ = (
        CheckConstraint("status in ('active', 'completed', 'archived')", name="ck_projects_status"),
        CheckConstraint("length(name) <= 120", name="ck_projects_name_len"),
        CheckConstraint("description is null or length(description) <= 8000", name="ck_projects_desc_len"),
        Index("idx_projects_user_space", "user_id", "space_id"),
        Index("idx_projects_status", "status"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=True)
    target_date: Mapped[date] = mapped_column(Date, nullable=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)

    space = relationship("Space", back_populates="projects")
    tasks = relationship("Task", back_populates="project")
    calendar_items = relationship("CalendarItem", back_populates="project")
