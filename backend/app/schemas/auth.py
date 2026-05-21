from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import ORMModel


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    display_name: Optional[str] = None
    timezone: str = "America/New_York"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class OwnerLoginRequest(BaseModel):
    access_code: str = Field(min_length=8)


class AppleSignInRequest(BaseModel):
    id_token: str = Field(min_length=1)
    bundle_id: str = Field(min_length=1)
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None


class EmailRequest(BaseModel):
    email: EmailStr


class EmailOTPVerifyRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserRead(ORMModel):
    id: str
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    timezone: str
    avatar_url: Optional[str] = None
    locale: str = "zh-Hans"
