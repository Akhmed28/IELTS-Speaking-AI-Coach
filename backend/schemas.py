# schemas.py

from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime

# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str
    name: Optional[str] = None

class UserUpdate(BaseModel):
    name: Optional[str] = None
    voice_preference: Optional[str] = None # <-- ADD THIS LINE

class User(UserBase):
    id: int
    name: Optional[str] = None
    is_verified: bool
    created_at: datetime
    voice_preference: Optional[str] = None # <-- ADD THIS LINE

    class Config:
        from_attributes = True

# --- Token Schemas ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- Auth Schemas ---
class VerificationRequest(BaseModel):
    email: EmailStr
    code: str
    type: Optional[str] = None

class ResetPasswordRequest(BaseModel):
    email: EmailStr

class NewPassword(BaseModel):
    new_password: str

class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str

class MessageResponse(BaseModel):
    message: str

class EmailRequest(BaseModel):
    email: EmailStr

# --- Conversation and Feedback Schemas ---
class QuestionAnswerPairDTO(BaseModel):
    question: str
    answer: str
    part: Optional[int] = None
    topic: Optional[str] = None
    answerLength: Optional[int] = None
    responseTime: Optional[float] = None

class ConversationPayload(BaseModel):
    conversation: List[QuestionAnswerPairDTO]

class ConversationRead(BaseModel):
    id: int
    conversation: List[QuestionAnswerPairDTO]
    created_at: datetime
    
    class Config:
        from_attributes = True

class SentenceFeedback(BaseModel):
    sentence: str
    feedback: str
    suggestion: str

class AnswerAnalysis(BaseModel):
    question: str
    answer: str
    grammar_feedback: List[SentenceFeedback]
    vocabulary_feedback: List[SentenceFeedback]
    fluency_feedback: str

class FeedbackResponse(BaseModel):
    overall_band_score: float
    fluency_score: int
    lexical_score: int
    grammar_score: int
    pronunciation_score: int
    general_summary: str
    answer_analyses: List[AnswerAnalysis]

class ConversationCreate(BaseModel):
    conversation: Dict[str, Any]
    
class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = None
