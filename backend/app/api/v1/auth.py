from datetime import datetime, timezone
from typing import Optional
from secrets import compare_digest

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db
from app.core.errors import AppError
from app.core.rate_limit import limiter
from app.core.security import decode_token
from app.models import RefreshTokenJTI, User
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
    return issue_tokens(user, db)


@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("3/hour")
def register(request: Request, payload: RegisterRequest, db: Session = Depends(get_db)):
    """v1.2.4 P2-1 (#5): registration is no longer publicly open.

    - In production (``APP_ENV=production``) with no invite token configured
      the endpoint behaves as if it doesn't exist (404). This keeps random
      internet scanners away from the user table.
    - Otherwise callers must present ``X-Invite-Token`` matching
      ``settings.register_invite_token``. In dev (both empty by default) the
      empty header still matches the empty config, so local workflows and
      the existing test suite keep working without touching headers.
    """
    settings = get_settings()
    invite_token = settings.register_invite_token or ""

    if settings.app_env == "production" and invite_token == "":
        raise AppError(
            status_code=404,
            code="not_found",
            message="Registration disabled.",
        )

    presented = request.headers.get("X-Invite-Token", "") or ""
    if not compare_digest(presented, invite_token):
        raise AppError(
            status_code=401,
            code="unauthorized",
            message="Invalid invite token.",
        )

    user = register_user(
        db,
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
        timezone=payload.timezone,
    )
    return issue_tokens(user, db)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, payload: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, payload.email, payload.password)
    return issue_tokens(user, db)


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
    # v1.2.4 P3-2 (#13): Apple Sign-In is gated off by default.
    # See settings.apple_sign_in_enabled for the rationale. We deliberately
    # return 404 (not 503) so scanners can't tell whether the endpoint
    # exists, and so v1.3.0 can flip the flag without touching code.
    if not get_settings().apple_sign_in_enabled:
        raise AppError(
            status_code=404,
            code="not_found",
            message="Apple Sign-In disabled.",
        )

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
    return issue_tokens(user, db)


def _as_aware_utc(value: datetime) -> datetime:
    """SQLite hands datetimes back as naive; Postgres keeps tz info."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("60/minute")
def refresh(request: Request, payload: RefreshRequest, db: Session = Depends(get_db)):
    """v1.2.4 P2-3 (#19): refresh now rotates and blacklists the presented jti.

    Contract changes vs. v1.2.3:
    - Missing / replayed / expired / revoked jti → 401 ``unauthorized``
    - On success the returned refresh_token is **always** new; clients MUST
      persist it. This applies to JWT-only callers (register / login /
      email-otp). Device-bound clients go through /auth/device-refresh.
    """
    decoded = decode_token(payload.refresh_token, expected_type="refresh")
    if not decoded:
        raise AppError(status_code=401, code="unauthorized", message="Invalid refresh token.")

    jti = decoded.get("jti")
    sub = decoded.get("sub")
    if not jti or not sub:
        raise AppError(status_code=401, code="unauthorized", message="Refresh token revoked.")

    row = db.scalar(select(RefreshTokenJTI).where(RefreshTokenJTI.jti == jti))
    now = datetime.now(timezone.utc)
    if (
        row is None
        or row.revoked_at is not None
        or _as_aware_utc(row.expires_at) <= now
    ):
        raise AppError(status_code=401, code="unauthorized", message="Refresh token revoked.")

    user = db.scalar(select(User).where(User.id == sub, User.deleted_at.is_(None)))
    if not user:
        raise AppError(status_code=401, code="unauthorized", message="User not found.")

    # Rotate: mark old jti revoked, then issue_tokens() persists the new one.
    row.revoked_at = now
    db.commit()

    return issue_tokens(user, db)


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
def device_logout(
    payload: DeviceLogoutRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Revoke a device session by device_id.

    v1.2.4 (#6): no longer open — caller must prove ownership of the session
    via either a valid access JWT (Authorization header) or the device's
    current refresh_token in the body. Otherwise an attacker who learns a
    device_id (which leaks to logs, screenshots, etc.) could nuke arbitrary
    sessions.
    """
    session = device_session_service.get(db, device_id=payload.device_id)
    if session is None or session.revoked_at is not None:
        # Already revoked — idempotent success.
        # We still 404 if there's literally no row for this device_id, so
        # callers can distinguish "you never had a session here" from
        # "your session got cleaned up".
        if session is None:
            raise AppError(
                status_code=404,
                code="not_found",
                message="Device session not found.",
            )
        return

    # Strategy 1: Authorization: Bearer <access_jwt>
    authorized = False
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        access_token = auth_header.split(" ", 1)[1].strip()
        decoded = decode_token(access_token, expected_type="access")
        if decoded and decoded.get("sub") == session.user_id:
            authorized = True

    # Strategy 2: body carries the current refresh_token
    if not authorized and payload.refresh_token:
        try:
            device_session_service.verify(
                db,
                device_id=payload.device_id,
                presented_refresh_token=payload.refresh_token,
            )
            authorized = True
        except AppError:
            authorized = False

    if not authorized:
        raise AppError(
            status_code=401,
            code="unauthorized",
            message="Device logout requires auth.",
        )

    device_session_service.revoke(db, device_id=payload.device_id)


@router.post("/logout")
def logout():
    return {"status": "ok"}
