from pydantic import BaseModel, EmailStr, Field

from app.schemas.user import UserResponse


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80, examples=["Hassan"])
    email: EmailStr = Field(examples=["hassan.sonder@app.com"])
    password: str = Field(min_length=8, examples=["sonderpass123"])


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class AuthResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str = "bearer"
