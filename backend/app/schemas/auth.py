from pydantic import BaseModel, EmailStr, Field

from app.schemas.user import UserResponse


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80, examples=["Hassan"])
    email: EmailStr = Field(examples=["hassan.sonder@app.com"])
    password: str = Field(min_length=8, max_length=128, examples=["sonderpass123"])


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=20, description="The ID token returned by Google Sign-In on the phone")


class AuthResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str = "bearer"
    # True when this request created the account (the app shows a welcome message).
    created: bool = False
    # The app must ask for the emailed code before the person can add friends or create moments.
    verification_required: bool = False


class VerifyEmailRequest(BaseModel):
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordRequest(BaseModel):
    # Needed when the account already has a password; Google-only accounts are setting their first one.
    current_password: str | None = Field(default=None, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
