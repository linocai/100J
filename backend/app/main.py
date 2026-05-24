from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import AppError, app_error_handler, http_error_handler
from app.core.rate_limit import limiter, rate_limit_handler


DEFAULT_JWT_SECRET = "change-me-in-development"
DEFAULT_LLM_SECRET = "change-me-32-byte-minimum-secret"
DEFAULT_LLM_SALT = b"100j-llm-v1"

MIN_SECRET_LENGTH = 32
MIN_SALT_LENGTH = 16
WEAK_SECRET_MARKERS = ("change-me",)


def _is_weak_secret(value: str) -> bool:
    if len(value) < MIN_SECRET_LENGTH:
        return True
    lowered = value.lower()
    return any(marker in lowered for marker in WEAK_SECRET_MARKERS)


def validate_runtime_settings() -> None:
    settings = get_settings()
    if settings.app_env != "production":
        return

    if settings.auth_mode == "local_owner":
        raise RuntimeError("AUTH_MODE=local_owner is not allowed in production.")

    if settings.jwt_secret_key == DEFAULT_JWT_SECRET or _is_weak_secret(settings.jwt_secret_key):
        raise RuntimeError(
            "JWT_SECRET_KEY must be set to a value with at least "
            f"{MIN_SECRET_LENGTH} characters and may not contain 'change-me' in production."
        )

    if settings.llm_key_encryption_secret == DEFAULT_LLM_SECRET or _is_weak_secret(
        settings.llm_key_encryption_secret
    ):
        raise RuntimeError(
            "LLM_KEY_ENCRYPTION_SECRET must be set to a value with at least "
            f"{MIN_SECRET_LENGTH} characters and may not contain 'change-me' in production."
        )

    if settings.llm_key_encryption_salt == DEFAULT_LLM_SALT or len(
        settings.llm_key_encryption_salt
    ) < MIN_SALT_LENGTH:
        raise RuntimeError(
            "LLM_KEY_ENCRYPTION_SALT must be overridden in production with at least "
            f"{MIN_SALT_LENGTH} bytes."
        )

    if settings.email_otp_enabled and not settings.smtp_host:
        raise RuntimeError(
            "SMTP_HOST must be configured when EMAIL_OTP_ENABLED=true in production."
        )


def create_app() -> FastAPI:
    validate_runtime_settings()
    settings = get_settings()
    app = FastAPI(title="Personal Affairs API", version="1.2.4")

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.state.limiter = limiter
    app.add_middleware(SlowAPIMiddleware)
    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(HTTPException, http_error_handler)
    app.add_exception_handler(RateLimitExceeded, rate_limit_handler)
    app.include_router(api_router, prefix="/api/v1")

    @app.get("/health")
    def health():
        return {"status": "ok"}

    return app


app = create_app()
