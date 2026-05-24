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
    llm_key_encryption_salt: bytes = b"100j-llm-v1"
    local_owner_email: str = "owner@100j.app"
    local_owner_display_name: str = "100J Owner"
    local_owner_timezone: str = "Asia/Shanghai"
    owner_cloud_access_code: str = ""
    email_otp_enabled: bool = True
    apple_allowed_audiences: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ["top.linotsai.app.PersonalAffairs"]
    )
    pending_confirmation_expire_minutes: int = 15
    cors_origins: Annotated[List[str], NoDecode] = Field(default_factory=list)

    # P0-1 new fields (default values preserve backward compatibility).
    refresh_token_rotation_enabled: bool = True
    refresh_token_blacklist_ttl_days: int = 31
    register_invite_token: str = ""
    rate_limit_otp_per_email_per_hour: int = 5

    # P0-5 SMTP config (empty defaults; prod must override when email OTP enabled).
    smtp_host: str = ""
    smtp_port: int = 465
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""

    @field_validator("cors_origins", "apple_allowed_audiences", mode="before")
    @classmethod
    def parse_string_list(cls, value):
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

    @field_validator("llm_key_encryption_salt", mode="before")
    @classmethod
    def parse_salt(cls, value):
        if isinstance(value, bytes):
            return value
        if isinstance(value, str):
            return value.encode("utf-8")
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
