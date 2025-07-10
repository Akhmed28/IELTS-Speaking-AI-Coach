import re
from fastapi import HTTPException, status

class PasswordValidator:
    MINIMUM_LENGTH = 6
    REQUIRED_SPECIAL_CHARS = set(["-", "_", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "+", "=", "[", "]", "{", "}", "|", "\\", ":", ";", "\"", "'", "<", ">", ",", ".", "?", "/", "~", "`"])
    
    @classmethod
    def validate_password(cls, password: str) -> None:
        """
        Validate password and raise HTTPException if invalid.
        Requirements:
        - At least 6 characters
        - Must contain at least one special character
        """
        if not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password field cannot be empty."
            )
        
        # Check minimum length
        if len(password) < cls.MINIMUM_LENGTH:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Password must be at least {cls.MINIMUM_LENGTH} characters long."
            )
        
        # Check for special characters
        password_chars = set(password)
        if password_chars.isdisjoint(cls.REQUIRED_SPECIAL_CHARS):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one special character (-, _, !, @, #, $, %, etc.)."
            )
    
    @classmethod
    def get_requirements_text(cls) -> str:
        return f"Password must be at least {cls.MINIMUM_LENGTH} characters and include special characters (-, _, !, @, #, $, %, etc.)" 