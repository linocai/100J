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
    # v1.1.2: 客户端可选附带设备信息以同时拿到 device-bound refresh token。
    device_id: Optional[str] = Field(default=None, min_length=8, max_length=64)
    device_name: Optional[str] = Field(default=None, max_length=128)
    platform: Optional[str] = Field(default=None, max_length=16)


class AppleSignInRequest(BaseModel):
    id_token: str = Field(min_length=1)
    bundle_id: str = Field(min_length=1)
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    device_id: Optional[str] = Field(default=None, min_length=8, max_length=64)
    device_name: Optional[str] = Field(default=None, max_length=128)
    platform: Optional[str] = Field(default=None, max_length=16)


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
    # v1.1.2: 当客户端传了 device_id，服务器附带 device session 字段。
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    expires_at: Optional[str] = None


class DeviceRefreshRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=64)
    refresh_token: str = Field(min_length=1)


class DeviceLogoutRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=64)
    refresh_token: Optional[str] = None  # 可选；服务器只按 device_id revoke


class UserRead(ORMModel):
    id: str
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    timezone: str
    avatar_url: Optional[str] = None
    locale: str = "zh-Hans"
