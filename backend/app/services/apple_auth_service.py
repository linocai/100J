import json
import logging
import time
import urllib.request
from typing import Optional

import jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.models import User
from app.services.auth_service import create_default_spaces

logger = logging.getLogger(__name__)

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
JWKS_TTL_SECONDS = 24 * 60 * 60
# P2-2 (#18): when Apple is unreachable we extend stale cache by this much
# so a transient outage doesn't lock every Apple user out for 24h.
JWKS_STALE_GRACE_SECONDS = 60 * 60

_jwks_cache: dict = {"expires_at": 0.0, "keys": None}


def _jwks() -> dict:
    """v1.2.4 P2-2 (#18): fall back to stale cache when Apple is unreachable.

    Previously a single failed fetch raised straight through, taking every
    in-flight Apple sign-in down. Now:

    * fresh cache → returned as-is (fast path)
    * stale cache + remote OK → refresh + cache
    * stale cache + remote down → log warning, extend ``expires_at`` by 1h,
      reuse stale keys (Apple rotates keys slowly, this is safe for a brief
      outage)
    * empty cache + remote down → 503 ``upstream_unavailable`` (first launch
      against a broken Apple endpoint; nothing else we can do)
    """
    now = time.time()
    if _jwks_cache["keys"] and _jwks_cache["expires_at"] > now:
        return _jwks_cache["keys"]

    try:
        with urllib.request.urlopen(APPLE_JWKS_URL, timeout=5) as response:
            keys = json.load(response)
    except Exception as exc:  # network errors, JSON errors, timeouts — all
        # collapse to "remote unavailable" so callers see one consistent
        # signal. We intentionally do NOT catch this in _verify_apple_id_token
        # because then a token-decode error would also pop a 503.
        if _jwks_cache["keys"]:
            logger.warning(
                "apple_jwks_unreachable, reusing stale cache for %ss: %s",
                JWKS_STALE_GRACE_SECONDS,
                exc,
            )
            _jwks_cache["expires_at"] = now + JWKS_STALE_GRACE_SECONDS
            return _jwks_cache["keys"]
        logger.error("apple_jwks_unreachable and no stale cache: %s", exc)
        raise AppError(
            status_code=503,
            code="upstream_unavailable",
            message="Apple JWKS unreachable.",
        )

    _jwks_cache["keys"] = keys
    _jwks_cache["expires_at"] = now + JWKS_TTL_SECONDS
    return keys


def _verify_apple_id_token(id_token: str, expected_audience: str) -> dict:
    try:
        headers = jwt.get_unverified_header(id_token)
    except jwt.InvalidTokenError as exc:
        raise AppError(401, "unauthorized", f"Invalid Apple identity token: {exc}")

    key_id = headers.get("kid")
    if not key_id:
        raise AppError(401, "unauthorized", "Apple key id missing.")

    key = next((item for item in _jwks().get("keys", []) if item.get("kid") == key_id), None)
    if not key:
        raise AppError(401, "unauthorized", "Apple key not found.")

    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))
    try:
        return jwt.decode(
            id_token,
            public_key,
            algorithms=["RS256"],
            audience=expected_audience,
            issuer=APPLE_ISSUER,
        )
    except jwt.InvalidTokenError as exc:
        raise AppError(401, "unauthorized", f"Invalid Apple identity token: {exc}")


def sign_in_with_apple(
    db: Session,
    id_token: str,
    email_hint: Optional[str],
    full_name_hint: Optional[str],
    bundle_id: str,
) -> User:
    settings = get_settings()
    if bundle_id not in settings.apple_allowed_audiences:
        raise AppError(401, "unauthorized", "Apple audience not allowed.")

    claims = _verify_apple_id_token(id_token, expected_audience=bundle_id)
    apple_user_id = claims["sub"]
    email = (claims.get("email") or email_hint or "").strip().lower() or None

    user = db.scalar(
        select(User).where(User.apple_user_id == apple_user_id, User.deleted_at.is_(None))
    )
    if user is None and email:
        user = db.scalar(select(User).where(User.email == email, User.deleted_at.is_(None)))
        if user:
            user.apple_user_id = apple_user_id

    if user is None:
        user = User(
            apple_user_id=apple_user_id,
            email=email,
            display_name=full_name_hint or email or "100J User",
            timezone="Asia/Shanghai",
            password_hash=None,
            locale="zh-Hans",
        )
        db.add(user)
        db.flush()

    create_default_spaces(db, user)
    db.commit()
    db.refresh(user)
    return user
