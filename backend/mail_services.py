from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
import os
from dotenv import load_dotenv
import ssl
import asyncio
from typing import Optional
from fastapi import HTTPException

load_dotenv()

# Create an SSL context with timeout settings
ssl_context = ssl.create_default_context()

conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv('MAIL_USERNAME'),
    MAIL_PASSWORD=os.getenv('MAIL_PASSWORD'),
    MAIL_FROM=os.getenv('MAIL_FROM'),
    MAIL_PORT=465,  # Force port 465 for SSL
    MAIL_SERVER="smtp.gmail.com",
    MAIL_SSL_TLS=True,
    MAIL_STARTTLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True,
    TEMPLATE_FOLDER=None,
    TIMEOUT=5  # 5 seconds timeout
)

fastmail = FastMail(conf)

async def send_email_with_retry(message: MessageSchema, max_retries: int = 2) -> Optional[Exception]:
    """Send email with retry logic and return any error that occurred"""
    last_error = None
    for attempt in range(max_retries):
        try:
            # Use asyncio.wait_for to add timeout
            await asyncio.wait_for(
                fastmail.send_message(message),
                timeout=5.0  # 5 seconds timeout
            )
            return None
        except asyncio.TimeoutError:
            last_error = Exception("Email sending timed out")
            print(f"Email sending attempt {attempt + 1} timed out")
        except Exception as e:
            last_error = e
            print(f"Email sending attempt {attempt + 1} failed: {str(e)}")
        
        if attempt < max_retries - 1:
            await asyncio.sleep(1)  # Wait 1 second before retrying
    return last_error

async def send_verification_email(email_to: str, code: str):
    message = MessageSchema(
        subject="Verify your IELTS Practice AI account",
        recipients=[email_to],
        body=f"""
        <html>
            <body>
                <h2>Welcome to IELTS Practice AI!</h2>
                <p>Your verification code is: <strong>{code}</strong></p>
                <p>This code will expire in 15 minutes.</p>
            </body>
        </html>
        """,
        subtype="html"
    )
    
    error = await send_email_with_retry(message)
    if error:
        print(f"Failed to send verification email: {str(error)}")
        if isinstance(error, asyncio.TimeoutError):
            raise HTTPException(
                status_code=504,
                detail="Email service timed out. Please try again."
            )
        raise HTTPException(
            status_code=500,
            detail="Failed to send verification email. Please try again later."
        )

async def send_password_reset_email(email_to: str, code: str):
    message = MessageSchema(
        subject="Reset your IELTS Practice AI password",
        recipients=[email_to],
        body=f"""
        <html>
            <body>
                <h2>Password Reset Request</h2>
                <p>Your password reset code is: <strong>{code}</strong></p>
                <p>This code will expire in 15 minutes.</p>
                <p>If you did not request a password reset, please ignore this email.</p>
            </body>
        </html>
        """,
        subtype="html"
    )
    
    error = await send_email_with_retry(message)
    if error:
        print(f"Failed to send password reset email: {str(error)}")
        if isinstance(error, asyncio.TimeoutError):
            raise HTTPException(
                status_code=504,
                detail="Email service timed out. Please try again."
            )
        raise HTTPException(
            status_code=500,
            detail="Failed to send password reset email. Please try again later."
        )
