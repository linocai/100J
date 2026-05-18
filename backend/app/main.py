from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import AppError, app_error_handler, http_error_handler


DEFAULT_JWT_SECRET = "change-me-in-development"
DEFAULT_LLM_SECRET = "change-me-32-byte-minimum-secret"


def validate_runtime_settings() -> None:
    settings = get_settings()
    if settings.app_env != "production":
        return

    if settings.auth_mode == "local_owner":
        raise RuntimeError("AUTH_MODE=local_owner is not allowed in production.")
    if settings.jwt_secret_key == DEFAULT_JWT_SECRET:
        raise RuntimeError("JWT_SECRET_KEY must be changed in production.")
    if settings.llm_key_encryption_secret == DEFAULT_LLM_SECRET:
        raise RuntimeError("LLM_KEY_ENCRYPTION_SECRET must be changed in production.")


def create_app() -> FastAPI:
    validate_runtime_settings()
    settings = get_settings()
    app = FastAPI(title="Personal Affairs API", version="0.1.0")

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(HTTPException, http_error_handler)
    app.include_router(api_router, prefix="/api/v1")

    @app.get("/health")
    def health():
        return {"status": "ok"}

    return app


app = create_app()
