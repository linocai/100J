from typing import Optional

from pydantic import BaseModel, Field


class RegisterDeviceRequest(BaseModel):
    platform: str = Field(min_length=2, max_length=16)
    token: str = Field(min_length=1, max_length=255)
    app_version: Optional[str] = Field(default=None, max_length=32)
