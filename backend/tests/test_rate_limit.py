"""P0-4 (#7): trusted-proxy key function must not let untrusted callers
forge X-Forwarded-For to share or impersonate rate-limit buckets.
"""

from types import SimpleNamespace
from typing import Optional

from starlette.datastructures import Headers

from app.core.rate_limit import trusted_proxy_key


def _request(client_host: str, *, headers: Optional[dict] = None):
    return SimpleNamespace(
        client=SimpleNamespace(host=client_host),
        headers=Headers(headers or {}),
    )


def test_key_func_trusts_xff_only_from_loopback():
    """When the direct peer is 127.0.0.1 (nginx terminating TLS in front of
    uvicorn), the first hop of X-Forwarded-For is the real client and must be
    used as the rate-limit key."""

    request = _request("127.0.0.1", headers={"x-forwarded-for": "203.0.113.5, 10.0.0.1"})

    key = trusted_proxy_key(request)

    assert key == "203.0.113.5"


def test_key_func_falls_back_to_remote_address_when_xff_from_outside():
    """When the direct peer is NOT loopback, X-Forwarded-For must be ignored —
    otherwise an outside attacker could share or evade buckets by sending the
    header themselves."""

    request = _request(
        "198.51.100.42", headers={"x-forwarded-for": "10.0.0.1"}
    )

    key = trusted_proxy_key(request)

    assert key == "198.51.100.42"


def test_key_func_handles_loopback_with_no_xff():
    request = _request("127.0.0.1")

    key = trusted_proxy_key(request)

    assert key == "127.0.0.1"


def test_key_func_ipv6_loopback_also_trusted():
    request = _request("::1", headers={"x-forwarded-for": "203.0.113.7"})

    key = trusted_proxy_key(request)

    assert key == "203.0.113.7"


def test_key_func_ignores_empty_xff_from_loopback():
    request = _request("127.0.0.1", headers={"x-forwarded-for": "   "})

    key = trusted_proxy_key(request)

    assert key == "127.0.0.1"
