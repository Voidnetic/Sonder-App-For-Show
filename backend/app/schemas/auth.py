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
