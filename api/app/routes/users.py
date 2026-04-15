from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, gravatar_url, hash_password, verify_password
from app.database import get_db
from app.models import Gratitude, User
from app.schemas import GratitudeResponse, UpdateEmailRequest, UpdatePasswordRequest, UserResponse, UserWithStreak
from app.streaks import calculate_streaks

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserWithStreak)
async def get_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    streaks = await calculate_streaks(db, user.id)
    return UserWithStreak(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        gravatar_url=gravatar_url(user.email),
        created_at=user.created_at,
        current_streak=streaks["current_streak"],
        longest_streak=streaks["longest_streak"],
    )


@router.get("", response_model=list[UserWithStreak])
async def list_users(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).order_by(User.display_name))
    users = result.scalars().all()

    response = []
    for u in users:
        streaks = await calculate_streaks(db, u.id)
        response.append(UserWithStreak(
            id=u.id,
            email=u.email,
            display_name=u.display_name,
            gravatar_url=gravatar_url(u.email),
            created_at=u.created_at,
            current_streak=streaks["current_streak"],
            longest_streak=streaks["longest_streak"],
        ))
    return response


@router.put("/me/email", response_model=UserResponse)
async def update_email(
    body: UpdateEmailRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect password")

    existing = await db.execute(select(User).where(User.email == body.new_email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already in use")

    user.email = body.new_email
    await db.commit()
    await db.refresh(user)
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        gravatar_url=gravatar_url(user.email),
        created_at=user.created_at,
    )


@router.put("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def update_password(
    body: UpdatePasswordRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect password")

    user.password_hash = hash_password(body.new_password)
    await db.commit()


@router.get("/{user_id}/gratitudes", response_model=list[GratitudeResponse])
async def get_user_gratitudes(
    user_id: UUID,
    _: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify user exists
    result = await db.execute(select(User).where(User.id == user_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    result = await db.execute(
        select(Gratitude)
        .where(Gratitude.user_id == user_id)
        .order_by(Gratitude.entry_date.desc())
    )
    return result.scalars().all()
