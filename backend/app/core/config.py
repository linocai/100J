import json
from functools import lru_cache
from typing import Annotated, List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_env: str = "development"
    auth_mode: str = "local_owner"
    database_url: str = "sqlite:///./personal_affairs.db"
    jwt_secret_key: str = "change-me-in-development"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30
    llm_key_encryption_secret: str = "change-me-32-byte-minimum-secret"
    local_owner_email: str = "owner@100j.app"
    local_owner_display_name: str = "100J Owner"
    local_owner_timezone: str = "Asia/Shanghai"
    owner_cloud_access_code: str = ""
    pending_confirmation_expire_minutes: int = 15
    cors_origins: Annotated[List[str], NoDecode] = Field(default_factory=list)

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value):
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                parsed = json.loads(stripped)
                if not isinstance(parsed, list):
                    raise ValueError("CORS_ORIGINS JSON value must be a list")
                return [str(item).strip() for item in parsed if str(item).strip()]
            return [item.strip() for item in stripped.split(",") if item.strip()]
        return value

    @field_validator("auth_mode")
    @classmethod
    def validate_auth_mode(cls, value):
        if value not in {"local_owner", "jwt"}:
            raise ValueError("AUTH_MODE must be local_owner or jwt")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
