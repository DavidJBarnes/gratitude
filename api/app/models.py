import uuid
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = mapped_column(String(255), unique=True, nullable=False)
    display_name = mapped_column(String(255), nullable=False)
    password_hash = mapped_column(String(255), nullable=False)
    created_at = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    gratitudes = relationship("Gratitude", back_populates="user", cascade="all, delete-orphan")


class Gratitude(Base):
    __tablename__ = "gratitudes"
    __table_args__ = (
        Index("ix_gratitudes_user_id", "user_id"),
        Index("ix_gratitudes_entry_date", "entry_date"),
    )

    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = mapped_column(String(255), nullable=False)
    description = mapped_column(Text, nullable=True)
    entry_date = mapped_column(Date, nullable=False)
    created_at = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="gratitudes")
