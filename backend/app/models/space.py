from sqlalchemy import CheckConstraint, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import IdMixin, TimestampMixin


class Space(IdMixin, TimestampMixin, Base):
    __tablename__ = "spaces"
    __table_args__ = (
        CheckConstraint("type in ('personal', 'company')", name="ck_spaces_type"),
        Index("idx_spaces_user_id", "user_id"),
        Index("idx_spaces_user_type", "user_id", "type"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False)

    user = relationship("User", back_populates="spaces")
    tasks = relationship("Task", back_populates="space")
    projects = relationship("Project", back_populates="space")
    calendar_items = relationship("CalendarItem", back_populates="space")
    notes = relationship("Note", back_populates="space")

