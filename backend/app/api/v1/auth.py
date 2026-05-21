from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import AppError
from app.core.rate_limit import limiter
from app.core.security import decode_token
from app.models import User
from app.schemas.auth import (
    AppleSignInRequest,
    EmailOTPVerifyRequest,
    EmailRequest,
    LoginRequest,
    OwnerLoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services.apple_auth_service import sign_in_with_apple
from app.services.auth_service import authenticate_owner_access_code, authenticate_user, issue_tokens, register_user
from app.services.email_otp_service import request_code, verify_code
from app.services.email_sender import get_email_sender

router = APIRouter(prefix="/auth", tags=["auth"])


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
    return issue_tokens(user)


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
    return issue_tokens(user)


@router.post("/email-otp/request", status_code=204)
@limiter.limit("5/minute")
def request_email_otp(request: Request, payload: EmailRequest, db: Session = Depends(get_db)):
    request_code(db, payload.email, send=get_email_sender())


@router.post("/email-otp/verify", response_model=TokenResponse)
@limiter.limit("20/minute")
def verify_email_otp(request: Request, payload: EmailOTPVerifyRequest, db: Session = Depends(get_db)):
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


@router.post("/logout")
def logout():
    return {"status": "ok"}
