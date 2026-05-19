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
