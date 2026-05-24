"""v1.2.4 P2-2 (#18) — Apple JWKS fetch resilience.

We import the module so we can mutate its `_jwks_cache` and patch
`urllib.request.urlopen` to simulate the upstream being down.
"""

from __future__ import annotations

import json
import time
from typing import Any

import pytest

import app.services.apple_auth_service as apple_auth_service
from app.core.errors import AppError


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
