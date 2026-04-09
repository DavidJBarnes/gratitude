from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.database import get_db
from app.models import User
from app.schemas import StreakResponse
from app.streaks import calculate_streaks

router = APIRouter(prefix="/streaks", tags=["streaks"])


@router.get("/me", response_model=StreakResponse)
async def get_my_streak(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    streaks = await calculate_streaks(db, user.id)
    return StreakResponse(**streaks)
