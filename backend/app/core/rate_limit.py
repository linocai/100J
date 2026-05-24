from typing import Optional

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.util import get_remote_address


LOOPBACK_HOSTS = {"127.0.0.1", "::1"}


def _client_host(request: Request) -> Optional[str]:
    client = getattr(request, "client", None)
    if client is None:
        return None
    return getattr(client, "host", None)


def trusted_proxy_key(request: Request) -> str:
    """Return the best-effort client IP.

    Trusts ``X-Forwarded-For`` **only** when the direct peer is loopback —
    matching the systemd ``--forwarded-allow-ips=127.0.0.1`` posture. When the
    direct peer is anything else (e.g. someone hit the uvicorn port directly
    from outside), we fall back to ``request.client.host`` so attackers cannot
    spoof their rate-limit bucket via the header.
    """

    direct_peer = _client_host(request)
    if direct_peer in LOOPBACK_HOSTS:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            first = forwarded.split(",", 1)[0].strip()
            if first:
                return first
    return get_remote_address(request)


def key_func_email(request: Request, payload_attr: str = "email") -> str:
    """Per-email key for OTP-style throttling.

    Falls back to IP when no email is present (e.g. malformed payload),
    preserving slowapi's expectation of a non-empty string.
    """

    candidate: Optional[str] = None
    payload = getattr(request, "_otp_payload", None)
    if isinstance(payload, dict):
        value = payload.get(payload_attr)
        if isinstance(value, str) and value.strip():
            candidate = value.strip().lower()
    if candidate:
        return f"otp:{candidate}"
    return f"ip:{trusted_proxy_key(request)}"


limiter = Limiter(key_func=trusted_proxy_key)


async def rate_limit_handler(_: Request, __) -> JSONResponse:
    return JSONResponse(
        status_code=429,
        content={
            "error": {
                "code": "rate_limited",
                "message": "Too many requests. Please try again later.",
                "details": {},
            }
        },
    )
