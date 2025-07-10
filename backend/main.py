# file: main.py

from dotenv import load_dotenv
load_dotenv()

from fastapi import File, UploadFile
from azure_tts_service import speech_to_text_from_bytes

from fastapi.responses import StreamingResponse
import io
import azure_tts_service
from fastapi import Depends, FastAPI, HTTPException, status, BackgroundTasks
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Any
import random
from datetime import datetime, timedelta
import json
import asyncio

import models
import schemas
import security
import crud
import ai_services
from database import engine, Base, get_db
from mail_services import send_verification_email, send_password_reset_email
from validation import PasswordValidator

async def create_db_and_tables():
    from models import User, Conversation 
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

app = FastAPI(
    title="IELTS Practice AI API",
    description="API to support the IELTS Speaking practice mobile application."
)

@app.on_event("startup")
async def on_startup():
    await create_db_and_tables()

# --- Authentication and Registration Endpoints ---

async def send_verification_email_background(email: str, code: str):
    try:
        await send_verification_email(email, code)
    except Exception as e:
        print(f"Background email sending failed: {e}")

@app.post("/text-to-speech")
async def text_to_speech_endpoint(request: schemas.TTSRequest):
    audio_bytes = await azure_tts_service.text_to_speech_async(request.text, voice_id=request.voice)
    if audio_bytes:
        return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")
    else:
        raise HTTPException(status_code=500, detail="Failed to generate speech audio.")

@app.post("/speech-to-text")
async def transcribe_speech(audio_file: UploadFile = File(...)):
    audio_bytes = await audio_file.read()
    transcription = await speech_to_text_from_bytes(audio_bytes)
    if "Error" in transcription:
        raise HTTPException(status_code=500, detail=transcription)
    return {"transcription": transcription}

@app.post("/register", status_code=status.HTTP_201_CREATED, response_model=schemas.MessageResponse)
async def register_user(
    user: schemas.UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    PasswordValidator.validate_password(user.password)
    db_user = await crud.get_user_by_email(db, email=user.email)
    if db_user:
        if db_user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email already exists and is verified. Please log in instead.",
            )
        else:
            verification_code = str(random.randint(100000, 999999))
            db_user.verification_code = verification_code
            db_user.code_expires_at = datetime.utcnow() + timedelta(minutes=15)
            db_user.name = user.name
            new_hashed_password = security.get_password_hash(user.password)
            db_user.hashed_password = new_hashed_password
            await db.commit()
            background_tasks.add_task(send_verification_email_background, user.email, verification_code)
            return {"message": "Verification code sent."}

    verification_code = str(random.randint(100000, 999999))
    await crud.create_user(db=db, user=user, verification_code=verification_code)
    background_tasks.add_task(send_verification_email_background, user.email, verification_code)
    return {"message": "Verification code sent."}

@app.post("/resend-verification", response_model=schemas.MessageResponse)
async def resend_verification_code(
    request: schemas.EmailRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    user = await crud.get_user_by_email(db, email=request.email)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found.")
    if user.is_verified:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Account is already verified.")
    verification_code = str(random.randint(100000, 999999))
    user.verification_code = verification_code
    user.code_expires_at = datetime.utcnow() + timedelta(minutes=15)
    await db.commit()
    background_tasks.add_task(send_verification_email_background, request.email, verification_code)
    return {"message": "New verification code sent."}

@app.post("/verify", response_model=schemas.Token)
async def verify_user_account(request: schemas.VerificationRequest, db: AsyncSession = Depends(get_db)):
    if request.type == "reset":
        user = await crud.check_reset_code(db, email=request.email, code=request.code)
        if not user:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired verification code.")
        reset_token = security.create_password_reset_token(email=user.email)
        return schemas.Token(access_token=reset_token, token_type="bearer")
    else:
        user = await crud.verify_user_code(db, email=request.email, code=request.code)
        if not user:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid email or verification code.")
        access_token = security.create_access_token(data={"sub": user.email})
        return schemas.Token(access_token=access_token, token_type="bearer")

@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    user = await crud.get_user_by_email(db, email=form_data.username)
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")
    if not user.is_verified:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Please verify your email first.")
    access_token = security.create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

# --- User Endpoints ---

@app.get("/users/me", response_model=schemas.User)
async def read_users_me(current_user: models.User = Depends(crud.get_current_active_user)):
    return current_user

# --- THIS ENDPOINT IS MODIFIED ---
@app.put("/users/me", response_model=schemas.User)
async def update_user_profile(
    user_update: schemas.UserUpdate,
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    # This generic approach handles updating any field present in the UserUpdate schema
    update_data = user_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(current_user, key, value)
    
    await db.commit()
    await db.refresh(current_user)
    return current_user

@app.delete("/users/me", response_model=schemas.MessageResponse)
async def delete_user_account(
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    await crud.delete_current_user(db, current_user)
    return {"message": "Account deleted successfully"}

@app.put("/users/me/password", response_model=schemas.MessageResponse)
async def change_current_user_password(
    form_data: schemas.PasswordChangeRequest,
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    PasswordValidator.validate_password(form_data.new_password)
    await crud.update_user_password(db=db, user=current_user, form_data=form_data)
    return {"message": "Password updated successfully"}

# --- IELTS Practice Endpoint ---

@app.post("/practice/final-feedback", response_model=schemas.FeedbackResponse)
async def get_final_feedback(
    payload: schemas.ConversationPayload,
    current_user: models.User = Depends(crud.get_current_active_user)
):
    if not payload.conversation:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Conversation history cannot be empty.")
    convo_list = [item.dict() for item in payload.conversation]
    feedback_data = await ai_services.get_ai_final_feedback(convo_list)
    return feedback_data

# --- Password Reset Flow ---

@app.post("/send-reset-code", response_model=schemas.MessageResponse)
async def send_reset_code(
    request: schemas.ResetPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    user = await crud.get_user_by_email(db, email=request.email)
    if not user:
        raise HTTPException(status_code=404, detail="Account with this email does not exist.")
    reset_code = str(random.randint(100000, 999999))
    user.verification_code = reset_code
    user.code_expires_at = datetime.utcnow() + timedelta(minutes=15)
    await db.commit()
    background_tasks.add_task(send_password_reset_email, user.email, reset_code)
    return {"message": "Password reset code sent successfully."}

async def verify_password_reset_token(token: str = Depends(OAuth2PasswordBearer(tokenUrl="token")), db: AsyncSession = Depends(get_db)) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials for password reset",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = security.decode_access_token(token)
        if payload is None or payload.get("scope") != "password_reset":
            raise credentials_exception
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except security.JWTError:
        raise credentials_exception
    user = await crud.get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return user

@app.post("/reset-password", response_model=schemas.MessageResponse)
async def confirm_password_reset(
    payload: schemas.NewPassword,
    current_user: models.User = Depends(verify_password_reset_token),
    db: AsyncSession = Depends(get_db)
):
    PasswordValidator.validate_password(payload.new_password)
    await crud.reset_user_password(db=db, user=current_user, new_password=payload.new_password)
    return {"message": "Your password has been successfully reset."}

# --- Conversation History Endpoints ---

@app.post("/conversations", response_model=schemas.ConversationRead)
async def save_conversation(
    payload: schemas.ConversationCreate,
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    convo = await crud.create_conversation(db, user_id=current_user.id, conversation=payload.conversation)
    return schemas.ConversationRead(
        id=convo.id,
        conversation=json.loads(convo.conversation_data),
        created_at=convo.created_at
    )

@app.get("/conversations", response_model=List[schemas.ConversationRead])
async def list_conversations(
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    convos = await crud.get_user_conversations(db, user_id=current_user.id)
    return [
        schemas.ConversationRead(
            id=convo.id,
            conversation=json.loads(convo.conversation_data),
            created_at=convo.created_at
        ) for convo in convos
    ]

@app.delete("/conversations/{conversation_id}", response_model=schemas.MessageResponse)
async def delete_conversation(
    conversation_id: int,
    current_user: models.User = Depends(crud.get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    return await crud.delete_conversation(db, user_id=current_user.id, conversation_id=conversation_id)

# --- Root Endpoint for Testing ---
@app.get("/")
def read_root():
    return {"message": "IELTS Practice AI Server is running!"}
