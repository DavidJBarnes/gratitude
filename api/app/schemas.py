from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr


# --- Auth ---

class RegisterRequest(BaseModel):
    email: EmailStr
    display_name: str
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    access_token: str
    user: "UserResponse"


# --- User ---

class UserResponse(BaseModel):
    id: UUID
    email: str
    display_name: str
    gravatar_url: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UserWithStreak(UserResponse):
    current_streak: int
    longest_streak: int


# --- Gratitude ---

class GratitudeCreate(BaseModel):
    title: str
    description: str | None = None
    entry_date: date | None = None


class GratitudeUpdate(BaseModel):
    title: str | None = None
    description: str | None = None


class GratitudeResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    description: str | None
    entry_date: date
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class GratitudeWithUser(GratitudeResponse):
    user: UserResponse


# --- Streaks ---

class StreakResponse(BaseModel):
    current_streak: int
    longest_streak: int
    total_entries: int
    streak_label: str
