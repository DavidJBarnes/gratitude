from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, gravatar_url
from app.database import get_db
from app.models import Gratitude, User
from app.schemas import GratitudeCreate, GratitudeResponse, GratitudeUpdate, GratitudeWithUser, UserResponse

router = APIRouter(prefix="/gratitudes", tags=["gratitudes"])


@router.post("", response_model=GratitudeResponse, status_code=status.HTTP_201_CREATED)
async def create_gratitude(
    body: GratitudeCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    entry_date = body.entry_date or date.today()

    # Check for duplicate entry on same date
    existing = await db.execute(
        select(Gratitude).where(Gratitude.user_id == user.id, Gratitude.entry_date == entry_date)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have a gratitude entry for this date",
        )

    gratitude = Gratitude(
        user_id=user.id,
        title=body.title,
        description=body.description,
        entry_date=entry_date,
    )
    db.add(gratitude)
    await db.commit()
    await db.refresh(gratitude)
    return gratitude


@router.get("", response_model=list[GratitudeResponse])
async def list_my_gratitudes(
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Gratitude)
        .where(Gratitude.user_id == user.id)
        .order_by(Gratitude.entry_date.desc())
        .limit(limit)
        .offset(offset)
    )
    return result.scalars().all()


@router.put("/{gratitude_id}", response_model=GratitudeResponse)
async def update_gratitude(
    gratitude_id: UUID,
    body: GratitudeUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Gratitude).where(Gratitude.id == gratitude_id, Gratitude.user_id == user.id))
    gratitude = result.scalar_one_or_none()
    if not gratitude:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Gratitude entry not found")

    if body.title is not None:
        gratitude.title = body.title
    if body.description is not None:
        gratitude.description = body.description

    await db.commit()
    await db.refresh(gratitude)
    return gratitude


@router.delete("/{gratitude_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_gratitude(
    gratitude_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Gratitude).where(Gratitude.id == gratitude_id, Gratitude.user_id == user.id))
    gratitude = result.scalar_one_or_none()
    if not gratitude:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Gratitude entry not found")

    await db.delete(gratitude)
    await db.commit()


@router.get("/feed", response_model=list[GratitudeWithUser])
async def feed(
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Gratitude)
        .options(selectinload(Gratitude.user))
        .order_by(Gratitude.entry_date.desc(), Gratitude.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    gratitudes = result.scalars().all()

    items = []
    for g in gratitudes:
        user_resp = UserResponse(
            id=g.user.id,
            email=g.user.email,
            display_name=g.user.display_name,
            gravatar_url=gravatar_url(g.user.email),
            created_at=g.user.created_at,
        )
        items.append(GratitudeWithUser(
            id=g.id,
            user_id=g.user_id,
            title=g.title,
            description=g.description,
            entry_date=g.entry_date,
            created_at=g.created_at,
            updated_at=g.updated_at,
            user=user_resp,
        ))
    return items
