from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import json

import models
import schemas
import security
from database import get_db

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- User Management ---

async def get_user(db: AsyncSession, user_id: int) -> Optional[models.User]:
    result = await db.execute(select(models.User).filter(models.User.id == user_id))
    return result.scalar_one_or_none()

async def get_user_by_email(db: AsyncSession, email: str) -> Optional[models.User]:
    result = await db.execute(select(models.User).filter(models.User.email == email))
    return result.scalar_one_or_none()

async def create_user(db: AsyncSession, user: schemas.UserCreate, verification_code: str) -> models.User:
    hashed_password = security.get_password_hash(user.password)
    db_user = models.User(
        email=user.email,
        name=user.name,
        hashed_password=hashed_password,
        verification_code=verification_code,
        code_expires_at=datetime.utcnow() + timedelta(minutes=15)
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user

async def verify_user_code(db: AsyncSession, email: str, code: str) -> Optional[models.User]:
    result = await db.execute(
        select(models.User).filter(
            models.User.email == email,
            models.User.verification_code == code,
            models.User.code_expires_at > datetime.utcnow()
        )
    )
    user = result.scalar_one_or_none()
    
    if user:
        user.is_verified = True
        user.verification_code = None
        user.code_expires_at = None
        await db.commit()
        await db.refresh(user)
        return user
    return None

async def verify_password_reset_code(db: AsyncSession, email: str, code: str) -> Optional[models.User]:
    result = await db.execute(
        select(models.User).filter(
            models.User.email == email,
            models.User.verification_code == code,
            models.User.code_expires_at > datetime.utcnow()
        )
    )
    user = result.scalar_one_or_none()
    
    if user:
        user.verification_code = None
        user.code_expires_at = None
        await db.commit()
        await db.refresh(user)
        return user
    return None

# Добавьте эту новую функцию
async def check_reset_code(db: AsyncSession, email: str, code: str) -> Optional[models.User]:
    """Проверяет код сброса пароля, не аннулируя его."""
    result = await db.execute(
        select(models.User).filter(
            models.User.email == email,
            models.User.verification_code == code,
            models.User.code_expires_at > datetime.utcnow()
        )
    )
    return result.scalar_one_or_none()

# Замените старую функцию reset_user_password на эту
async def reset_user_password(db: AsyncSession, user: models.User, new_password: str):
    """Хеширует и устанавливает новый пароль, а также аннулирует все коды сброса."""
    user.hashed_password = security.get_password_hash(new_password)
    user.verification_code = None
    user.code_expires_at = None
    await db.commit()
    await db.refresh(user)

async def update_user_password(
    db: AsyncSession, user: models.User, form_data: schemas.PasswordChangeRequest
):
    if not security.verify_password(form_data.current_password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    user.hashed_password = security.get_password_hash(form_data.new_password)
    await db.commit()

# --- Conversation Management ---

async def create_conversation(db: AsyncSession, user_id: int, conversation: Dict[str, Any]) -> models.Conversation:
    db_conversation = models.Conversation(
        user_id=user_id,
        conversation_data=json.dumps(conversation),
        created_at=datetime.utcnow()
    )
    db.add(db_conversation)
    await db.commit()
    await db.refresh(db_conversation)
    return db_conversation

async def get_user_conversations(db: AsyncSession, user_id: int) -> list[models.Conversation]:
    result = await db.execute(
        select(models.Conversation)
        .filter(models.Conversation.user_id == user_id)
        .order_by(models.Conversation.created_at.desc())
    )
    return list(result.scalars().all())

async def delete_conversation(
    db: AsyncSession, user_id: int, conversation_id: int
) -> schemas.MessageResponse:
    result = await db.execute(
        select(models.Conversation).filter(
            models.Conversation.id == conversation_id,
            models.Conversation.user_id == user_id
        )
    )
    conversation = result.scalar_one_or_none()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    await db.delete(conversation)
    await db.commit()
    return {"message": "Conversation deleted successfully"}

# --- Authentication Helpers ---

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = security.decode_access_token(token)
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except Exception:
        raise credentials_exception
    
    user = await get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(
    current_user: models.User = Depends(get_current_user)
) -> models.User:
    if not current_user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not verified"
        )
    return current_user

async def delete_current_user(db: AsyncSession, user: models.User):
    await db.delete(user)
    await db.commit()
