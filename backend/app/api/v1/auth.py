from typing import Optional

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db
from app.core.errors import AppError
from app.core.rate_limit import limiter
from app.core.security import decode_token
from app.models import User
from app.schemas.auth import (
    AppleSignInRequest,
    DeviceLogoutRequest,
    DeviceRefreshRequest,
    EmailOTPVerifyRequest,
    EmailRequest,
    LoginRequest,
    OwnerLoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services import device_session_service
from app.services.apple_auth_service import sign_in_with_apple
from app.services.auth_service import authenticate_owner_access_code, authenticate_user, issue_tokens, register_user
from app.services.email_otp_service import request_code, verify_code
from app.services.email_sender import get_email_sender

router = APIRouter(prefix="/auth", tags=["auth"])


def _bundle_response(
    user: User,
    *,
    device_id: Optional[str],
    device_name: Optional[str],
    platform: Optional[str],
    db: Session,
) -> dict:
    """Helper: 如果客户端附带 device_id，颁发 device session；否则退回 JWT refresh。"""
    if device_id:
        issued = device_session_service.issue(
            db,
            user=user,
            device_id=device_id,
            device_name=device_name,
            platform=platform or "macos",
        )
        return issued.to_response()
    return issue_tokens(user)


@router.post("/register", response_model=TokenResponse, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    user = register_user(
        db,
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
        timezone=payload.timezone,
    )
    return issue_tokens(user)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, payload: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, payload.email, payload.password)
    return issue_tokens(user)


@router.post("/owner-login", response_model=TokenResponse)
@limiter.limit("5/minute")
def owner_login(request: Request, payload: OwnerLoginRequest, db: Session = Depends(get_db)):
    user = authenticate_owner_access_code(db, payload.access_code)
    return _bundle_response(
        user,
        device_id=payload.device_id,
        device_name=payload.device_name,
        platform=payload.platform,
        db=db,
    )


@router.post("/apple", response_model=TokenResponse)
@limiter.limit("5/minute")
def apple_sign_in(request: Request, payload: AppleSignInRequest, db: Session = Depends(get_db)):
    user = sign_in_with_apple(
        db,
        id_token=payload.id_token,
        email_hint=payload.email,
        full_name_hint=payload.full_name,
        bundle_id=payload.bundle_id,
    )
    return _bundle_response(
        user,
        device_id=payload.device_id,
        device_name=payload.device_name,
        platform=payload.platform,
        db=db,
    )


@router.post("/email-otp/request", status_code=204)
@limiter.limit("5/minute")
def request_email_otp(request: Request, payload: EmailRequest, db: Session = Depends(get_db)):
    if not get_settings().email_otp_enabled:
        raise AppError(status_code=404, code="not_found", message="Email OTP is not enabled.")
    request_code(db, payload.email, send=get_email_sender())


@router.post("/email-otp/verify", response_model=TokenResponse)
@limiter.limit("20/minute")
def verify_email_otp(request: Request, payload: EmailOTPVerifyRequest, db: Session = Depends(get_db)):
    if not get_settings().email_otp_enabled:
        raise AppError(status_code=404, code="not_found", message="Email OTP is not enabled.")
    user = verify_code(db, payload.email, payload.code)
    return issue_tokens(user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    decoded = decode_token(payload.refresh_token, expected_type="refresh")
    if not decoded:
        raise AppError(status_code=401, code="unauthorized", message="Invalid refresh token.")
    user = db.scalar(select(User).where(User.id == decoded.get("sub"), User.deleted_at.is_(None)))
    if not user:
        raise AppError(status_code=401, code="unauthorized", message="User not found.")
    return issue_tokens(user)


@router.post("/device-refresh", response_model=TokenResponse)
@limiter.limit("60/minute")
def device_refresh(request: Request, payload: DeviceRefreshRequest, db: Session = Depends(get_db)):
    """v1.1.2: 用 device-bound refresh token 静默换 access token。

    每次调用会 rotate refresh token，旧 token 立刻失效；客户端必须保存新返回的 refresh token。
    """
    issued = device_session_service.rotate(
        db,
        device_id=payload.device_id,
        presented_refresh_token=payload.refresh_token,
    )
    return issued.to_response()


@router.post("/device-logout", status_code=204)
def device_logout(payload: DeviceLogoutRequest, db: Session = Depends(get_db)):
    """Revoke a device session by device_id. Idempotent."""
    device_session_service.revoke(db, device_id=payload.device_id)


@router.post("/logout")
def logout():
    return {"status": "ok"}
