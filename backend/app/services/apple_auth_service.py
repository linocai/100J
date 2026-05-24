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


def _match_existing_user(
    db: Session,
    apple_user_id: str,
    apple_email: Optional[str],
) -> Optional[User]:
    """v1.2.4 P3-1 (#2): match an existing user *only* by trusted signals.

    Trusted signals are:
    - ``apple_user_id`` (Apple's ``sub`` claim — cryptographically bound to
      the verified id_token).
    - ``apple_email`` — Apple's ``email`` claim in the verified id_token.

    Crucially the client-supplied ``email_hint`` is **not** used here.
    Previously a hostile client could pass ``email=victim@example.com`` in
    the request body, sign in with their own Apple account, and silently
    take over the victim's existing local user row via the email-match
    branch. That's the vulnerability this helper closes.

    Returns the existing User (linking apple_user_id onto it if matched by
    email) or None when no trusted match exists.
    """
    user = db.scalar(
        select(User).where(User.apple_user_id == apple_user_id, User.deleted_at.is_(None))
    )
    if user is not None:
        return user

    if apple_email:
        user = db.scalar(select(User).where(User.email == apple_email, User.deleted_at.is_(None)))
        if user is not None:
            user.apple_user_id = apple_user_id
            return user

    return None


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

    # v1.2.4 P3-1 (#2): apple_email comes from the signed id_token claim and
    # is trusted; email_hint comes from the request body and is *not*. Only
    # apple_email participates in "match an existing user by email".
    apple_email = (claims.get("email") or "").strip().lower() or None
    hint_email = (email_hint or "").strip().lower() or None

    user = _match_existing_user(db, apple_user_id, apple_email)

    if user is None:
        # New user. Prefer the verified Apple email; fall back to the
        # client-supplied hint as a UX nicety (only for display/initial
        # email seed — it has zero authority to match existing accounts).
        # If neither is available, mint a stable private.local placeholder
        # so anything downstream that expects a non-empty email keeps
        # working without crashing.
        initial_email = apple_email or hint_email or f"apple-{apple_user_id[:8]}@private.local"

        # Defense in depth: if the hint email happens to collide with an
        # existing local user (different apple sub — we already proved that
        # via `_match_existing_user` above), do NOT raise a UNIQUE error
        # at INSERT time. Instead fall back to the private.local placeholder.
        # Without this an attacker could DoS new user creation by passing
        # any known email as the hint.
        if initial_email != apple_email and db.scalar(
            select(User).where(User.email == initial_email, User.deleted_at.is_(None))
        ) is not None:
            initial_email = f"apple-{apple_user_id[:8]}@private.local"

        user = User(
            apple_user_id=apple_user_id,
            email=initial_email,
            display_name=full_name_hint or initial_email or "100J User",
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
