from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.database import get_db
from app.models import User
from app.schemas import StreakResponse
from app.streaks import calculate_streaks

router = APIRouter(prefix="/streaks", tags=["streaks"])


@router.get("/me", response_model=StreakResponse)
async def get_my_streak(
    today: Optional[date] = Query(None, description="Client's local date (YYYY-MM-DD)"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    streaks = await calculate_streaks(db, user.id, client_today=today)
    return StreakResponse(**streaks)
