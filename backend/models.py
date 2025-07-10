# In models.py
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.dialects.sqlite import JSON
from sqlalchemy.orm import relationship
from database import Base
import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=True)  # User's full name
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # --- NEW FIELDS ---
    is_verified = Column(Boolean, default=False)
    verification_code = Column(String, nullable=True)
    code_expires_at = Column(DateTime(timezone=True), nullable=True)
    
    # --- ADD THIS LINE ---
    voice_preference = Column(String, nullable=True, default="female_us")


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    conversation_data = Column(Text, nullable=False)  # Store as JSON string
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", backref="conversations")