from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import create_access_token, create_refresh_token, decode_refresh_token, gravatar_url, hash_password, verify_password
from app.database import get_db
from app.models import User
from app.schemas import AuthResponse, LoginRequest, RefreshRequest, RegisterRequest, UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=body.email,
        display_name=body.display_name,
        password_hash=hash_password(body.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    access = create_access_token(user.id)
    refresh = create_refresh_token(user.id)
    user_resp = UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        gravatar_url=gravatar_url(user.email),
        created_at=user.created_at,
    )
    return AuthResponse(access_token=access, refresh_token=refresh, user=user_resp)


@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    access = create_access_token(user.id)
    refresh = create_refresh_token(user.id)
    user_resp = UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        gravatar_url=gravatar_url(user.email),
        created_at=user.created_at,
    )
    return AuthResponse(access_token=access, refresh_token=refresh, user=user_resp)


@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    user_id = decode_refresh_token(body.refresh_token)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    access = create_access_token(user.id)
    refresh = create_refresh_token(user.id)
    user_resp = UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        gravatar_url=gravatar_url(user.email),
        created_at=user.created_at,
    )
    return AuthResponse(access_token=access, refresh_token=refresh, user=user_resp)
