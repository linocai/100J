"""v1.2.4 P2-2 (#18) — Apple JWKS fetch resilience.

We import the module so we can mutate its `_jwks_cache` and patch
`urllib.request.urlopen` to simulate the upstream being down.

v1.2.4 P3-1 / P3-2 (#2, #13) tests are appended at the bottom of this
file: they cover the email_hint trust-boundary fix and the
`apple_sign_in_enabled` feature flag that returns 404 by default.
"""

from __future__ import annotations

import json
import time
from typing import Any

import pytest

import app.services.apple_auth_service as apple_auth_service
from app.core.config import get_settings
from app.core.errors import AppError
from app.models import User
from tests.conftest import TestingSessionLocal


def _seed_cache(keys: dict[str, Any], expires_at: float) -> None:
    apple_auth_service._jwks_cache["keys"] = keys
    apple_auth_service._jwks_cache["expires_at"] = expires_at


def _clear_cache() -> None:
    apple_auth_service._jwks_cache["keys"] = None
    apple_auth_service._jwks_cache["expires_at"] = 0.0


def _patch_urlopen_raising(monkeypatch, exc: Exception) -> None:
    def _boom(*_args, **_kwargs):
        raise exc

    monkeypatch.setattr(apple_auth_service.urllib.request, "urlopen", _boom)


def _patch_urlopen_returning(monkeypatch, body: dict) -> None:
    class _FakeResponse:
        def __init__(self, payload: dict) -> None:
            self._payload = payload

        def read(self) -> bytes:
            return json.dumps(self._payload).encode("utf-8")

        def __enter__(self):
            return self

        def __exit__(self, *_exc) -> None:
            return None

    monkeypatch.setattr(
        apple_auth_service.urllib.request,
        "urlopen",
        lambda *args, **kwargs: _FakeResponse(body),
    )


def test_apple_sign_in_falls_back_to_stale_jwks_when_remote_unreachable(monkeypatch):
    """When Apple is down but we have stale cache, return cached keys and
    extend the cache TTL by 1h instead of bricking every Apple login."""

    stale_keys = {"keys": [{"kid": "stale-key", "kty": "RSA"}]}
    # Stale means expires_at < now.
    _seed_cache(stale_keys, expires_at=time.time() - 60)
    _patch_urlopen_raising(monkeypatch, OSError("connection refused"))

    try:
        result = apple_auth_service._jwks()
        # Capture cache state BEFORE the finally clears it.
        post_expires_at = apple_auth_service._jwks_cache["expires_at"]
        post_keys = apple_auth_service._jwks_cache["keys"]
    finally:
        _clear_cache()

    assert result == stale_keys
    # Cache must have been extended into the future (within the grace window).
    assert post_expires_at > time.time()
    # And the cached keys must still be the stale ones (we did NOT clear them).
    assert post_keys == stale_keys


def test_apple_jwks_raises_503_when_no_cache_and_remote_down(monkeypatch):
    """First launch + Apple down = 503 upstream_unavailable, not a generic 500."""

    _clear_cache()
    _patch_urlopen_raising(monkeypatch, OSError("connection refused"))

    try:
        with pytest.raises(AppError) as excinfo:
            apple_auth_service._jwks()
    finally:
        _clear_cache()

    assert excinfo.value.status_code == 503
    assert excinfo.value.code == "upstream_unavailable"


def test_apple_jwks_refreshes_when_cache_expired_and_remote_ok(monkeypatch):
    """Sanity: when remote is reachable we replace stale cache with the fresh fetch."""

    _seed_cache({"keys": [{"kid": "old"}]}, expires_at=time.time() - 60)
    fresh = {"keys": [{"kid": "fresh"}]}
    _patch_urlopen_returning(monkeypatch, fresh)

    try:
        result = apple_auth_service._jwks()
    finally:
        _clear_cache()

    assert result == fresh


# ---------------------------------------------------------------------------
# v1.2.4 P3-1 (#2) — email_hint trust boundary
# ---------------------------------------------------------------------------
#
# We patch `_verify_apple_id_token` directly so we don't need a real Apple
# signing key. The fake returns whatever claim dict the test passed in.

BUNDLE_ID = "top.linotsai.app.PersonalAffairs"


def _stub_verify(monkeypatch, claims: dict) -> None:
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda _id_token, expected_audience: claims,
    )


def test_apple_email_hint_does_not_match_existing_user_when_claim_missing_email(monkeypatch):
    """The headline #2 fix: a client-supplied email must NOT be allowed to
    silently take over an existing local user. Previously a hostile client
    could pass `email=victim@example.com` and link their Apple sub to the
    victim's row. Now: claim has no email → email_hint is ignored for
    matching, a brand-new user is created instead. (Because the hint also
    happens to collide with the victim's row, the new-user's email seed
    falls back to the private.local placeholder — see the dedicated
    collision test below.)
    """
    _stub_verify(monkeypatch, {"sub": "000001.attackerattacker.0001", "email": None})

    with TestingSessionLocal() as db:
        victim = User(
            email="victim@example.com",
            password_hash="x",
            display_name="Victim",
            timezone="UTC",
        )
        db.add(victim)
        db.commit()
        db.refresh(victim)
        victim_id = victim.id

        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint="victim@example.com",
            full_name_hint=None,
            bundle_id=BUNDLE_ID,
        )

        assert user.id != victim_id, "email_hint MUST NOT match an existing user"
        assert user.apple_user_id == "000001.attackerattacker.0001"

        # Victim row must be untouched (no Apple linkage hijack).
        db.refresh(victim)
        assert victim.apple_user_id is None
        assert victim.email == "victim@example.com"


def test_apple_email_claim_matches_existing_user(monkeypatch):
    """The flip side: when the claim *does* carry an email, it's trusted
    (Apple signed the id_token), so we may link the Apple sub onto the
    existing row with that email."""
    _stub_verify(
        monkeypatch,
        {"sub": "apple-trusted-sub", "email": "owner@example.com"},
    )

    with TestingSessionLocal() as db:
        existing = User(
            email="owner@example.com",
            password_hash="x",
            display_name="Owner",
            timezone="UTC",
        )
        db.add(existing)
        db.commit()
        db.refresh(existing)
        existing_id = existing.id

        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint=None,
            full_name_hint=None,
            bundle_id=BUNDLE_ID,
        )

        assert user.id == existing_id
        assert user.apple_user_id == "apple-trusted-sub"


def test_apple_new_user_uses_email_claim_when_present(monkeypatch):
    """Greenfield user with email in the claim → that email lands on the row."""
    _stub_verify(
        monkeypatch,
        {"sub": "apple-new-1", "email": "Fresh@Example.COM"},
    )

    with TestingSessionLocal() as db:
        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint="hint-should-be-ignored@example.com",
            full_name_hint="Fresh User",
            bundle_id=BUNDLE_ID,
        )

        # Normalized to lower-case by the service.
        assert user.email == "fresh@example.com"
        assert user.apple_user_id == "apple-new-1"
        assert user.display_name == "Fresh User"


def test_apple_new_user_uses_hint_when_claim_email_missing(monkeypatch):
    """Greenfield user with no claim email but a hint → hint is allowed for
    seed/display only (no existing user has that email so it can't be used
    to take anything over)."""
    _stub_verify(monkeypatch, {"sub": "apple-new-2", "email": None})

    with TestingSessionLocal() as db:
        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint="Greenfield@example.com",
            full_name_hint=None,
            bundle_id=BUNDLE_ID,
        )

        assert user.email == "greenfield@example.com"
        assert user.apple_user_id == "apple-new-2"


def test_apple_new_user_falls_back_to_private_local_placeholder(monkeypatch):
    """Greenfield user with neither claim email nor hint → stable
    apple-XXXX@private.local placeholder so downstream code that expects
    a non-empty email keeps working. Apple subs are opaque random
    strings (e.g. `001234.deadbeefcafef00d.0123`) — using the first 8
    chars keeps the placeholder unique across users without exposing
    the full sub."""
    _stub_verify(monkeypatch, {"sub": "001234.deadbeefcafef00d.0123", "email": None})

    with TestingSessionLocal() as db:
        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint=None,
            full_name_hint=None,
            bundle_id=BUNDLE_ID,
        )

        assert user.email == "apple-001234.d@private.local"
        assert user.apple_user_id == "001234.deadbeefcafef00d.0123"


def test_apple_hint_collision_with_existing_user_falls_back_to_placeholder(monkeypatch):
    """v1.2.4 P3-1 defense-in-depth: if the client-supplied hint happens to
    collide with an existing local user's email (different Apple sub), we
    DO NOT raise a UNIQUE-constraint error — we fall back to the
    private.local placeholder. This prevents a hostile client from DoS'ing
    new-user creation by stuffing a known email into the hint field."""
    _stub_verify(monkeypatch, {"sub": "001234.beefbeefbeefbeef.0001", "email": None})

    with TestingSessionLocal() as db:
        # Existing local user with no Apple link.
        existing = User(
            email="collision@example.com",
            password_hash="x",
            display_name="Existing",
            timezone="UTC",
        )
        db.add(existing)
        db.commit()

        user = apple_auth_service.sign_in_with_apple(
            db,
            id_token="ignored",
            email_hint="collision@example.com",
            full_name_hint=None,
            bundle_id=BUNDLE_ID,
        )

        assert user.email == "apple-001234.b@private.local"
        assert user.apple_user_id == "001234.beefbeefbeefbeef.0001"


# ---------------------------------------------------------------------------
# v1.2.4 P3-2 (#13) — apple_sign_in_enabled feature flag
# ---------------------------------------------------------------------------


def test_apple_endpoint_returns_404_when_disabled(client):
    """Default v1.2.4 posture: APPLE_SIGN_IN_ENABLED=false → 404 not_found,
    with no token verification work happening at all."""
    # The default settings already have apple_sign_in_enabled=False, but
    # be explicit so the test still passes if a future dev flips the default.
    get_settings.cache_clear()
    try:
        response = client.post(
            "/api/v1/auth/apple",
            json={
                "id_token": "anything",
                "bundle_id": BUNDLE_ID,
                "email": None,
                "full_name": None,
            },
        )
    finally:
        get_settings.cache_clear()

    assert response.status_code == 404, response.text
    assert response.json()["error"]["code"] == "not_found"


def test_apple_endpoint_routes_through_when_enabled(client, monkeypatch):
    """When the flag is flipped on, the endpoint must reach the service
    layer (i.e. not short-circuit at the gate). We stub the verifier so
    the test doesn't need real Apple keys, and assert that a token is
    issued — proving the gate passed and the existing flow still works."""
    monkeypatch.setenv("APPLE_SIGN_IN_ENABLED", "true")
    get_settings.cache_clear()
    _stub_verify(
        monkeypatch,
        {"sub": "apple-gated-on", "email": "gated@example.com"},
    )
    try:
        response = client.post(
            "/api/v1/auth/apple",
            json={
                "id_token": "ignored",
                "bundle_id": BUNDLE_ID,
                "email": None,
                "full_name": "Gated Tester",
            },
        )
    finally:
        get_settings.cache_clear()

    assert response.status_code == 200, response.text
    body = response.json()
    assert body.get("access_token")
    assert body.get("refresh_token")
