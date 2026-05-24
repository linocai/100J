from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

import app.api.v1.auth as auth_module
import app.services.apple_auth_service as apple_auth_service
import app.services.device_session_service as device_session_service
import app.services.email_otp_service as email_otp_service
from app.core.config import get_settings
from app.models import DeviceSession, DeviceToken, EmailOTPCode, RefreshTokenJTI, Task, User
from tests.conftest import TestingSessionLocal, register_and_auth


def test_apple_signin_creates_default_spaces_and_reuses_sub(client, monkeypatch):
    # v1.2.4 P3-2: the endpoint is gated off by default; enable for this
    # behavior test that proves the service-layer logic still works when
    # the flag is on.
    monkeypatch.setenv("APPLE_SIGN_IN_ENABLED", "true")
    get_settings.cache_clear()
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {
            "sub": "apple-sub-1",
            "email": "apple@example.com",
        },
    )

    try:
        first = client.post(
            "/api/v1/auth/apple",
            json={"id_token": "token-1", "bundle_id": "top.linotsai.app.PersonalAffairs"},
        )
        assert first.status_code == 200, first.text
        headers = {"Authorization": f"Bearer {first.json()['access_token']}"}
        me = client.get("/api/v1/me", headers=headers).json()
        assert me["email"] == "apple@example.com"

        spaces = client.get("/api/v1/spaces", headers=headers).json()["items"]
        assert {space["type"] for space in spaces} == {"personal", "company"}

        second = client.post(
            "/api/v1/auth/apple",
            json={"id_token": "token-2", "bundle_id": "top.linotsai.app.PersonalAffairs"},
        )
        assert second.status_code == 200, second.text
        headers = {"Authorization": f"Bearer {second.json()['access_token']}"}
        assert client.get("/api/v1/me", headers=headers).json()["id"] == me["id"]
    finally:
        get_settings.cache_clear()


def test_apple_signin_binds_existing_email_user(client, monkeypatch):
    headers, _ = register_and_auth(client)
    original_id = client.get("/api/v1/me", headers=headers).json()["id"]
    # v1.2.4 P3-2: enable the gated endpoint for this behavior test.
    monkeypatch.setenv("APPLE_SIGN_IN_ENABLED", "true")
    get_settings.cache_clear()
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {
            "sub": "apple-sub-existing",
            "email": "user@example.com",
        },
    )

    try:
        response = client.post(
            "/api/v1/auth/apple",
            json={"id_token": "token", "bundle_id": "top.linotsai.app.PersonalAffairs"},
        )

        assert response.status_code == 200, response.text
        apple_headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
        assert client.get("/api/v1/me", headers=apple_headers).json()["id"] == original_id
    finally:
        get_settings.cache_clear()


def test_apple_signin_rejects_unknown_audience(client, monkeypatch):
    # v1.2.4 P3-2: enable the gated endpoint so we still reach the
    # audience-validation branch (otherwise we'd 404 before getting there).
    monkeypatch.setenv("APPLE_SIGN_IN_ENABLED", "true")
    get_settings.cache_clear()
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {"sub": "apple-sub-2"},
    )

    try:
        response = client.post(
            "/api/v1/auth/apple",
            json={"id_token": "token", "bundle_id": "com.example.other"},
        )

        assert response.status_code == 401
    finally:
        get_settings.cache_clear()


def test_email_otp_login_success_creates_default_spaces(client, monkeypatch):
    sent = []
    monkeypatch.setattr(
        auth_module,
        "get_email_sender",
        lambda: lambda email, code: sent.append((email, code)),
    )

    requested = client.post("/api/v1/auth/email-otp/request", json={"email": "OTP@Example.com"})
    assert requested.status_code == 204, requested.text
    assert sent[0][0] == "otp@example.com"

    verified = client.post(
        "/api/v1/auth/email-otp/verify",
        json={"email": "otp@example.com", "code": sent[0][1]},
    )
    assert verified.status_code == 200, verified.text
    headers = {"Authorization": f"Bearer {verified.json()['access_token']}"}
    assert client.get("/api/v1/me", headers=headers).json()["email"] == "otp@example.com"
    spaces = client.get("/api/v1/spaces", headers=headers).json()["items"]
    assert {space["type"] for space in spaces} == {"personal", "company"}


def test_email_otp_six_wrong_attempts_returns_429(client, monkeypatch):
    sent = []
    monkeypatch.setattr(
        auth_module,
        "get_email_sender",
        lambda: lambda email, code: sent.append((email, code)),
    )
    response = client.post("/api/v1/auth/email-otp/request", json={"email": "otp@example.com"})
    assert response.status_code == 204, response.text

    for _ in range(5):
        wrong = client.post(
            "/api/v1/auth/email-otp/verify",
            json={"email": "otp@example.com", "code": "000000"},
        )
        assert wrong.status_code == 401

    limited = client.post(
        "/api/v1/auth/email-otp/verify",
        json={"email": "otp@example.com", "code": "000000"},
    )
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limited"


def test_email_otp_request_is_rate_limited(client, monkeypatch):
    monkeypatch.setattr(auth_module, "get_email_sender", lambda: lambda email, code: None)

    for _ in range(5):
        response = client.post("/api/v1/auth/email-otp/request", json={"email": "otp@example.com"})
        assert response.status_code == 204, response.text

    response = client.post("/api/v1/auth/email-otp/request", json={"email": "otp@example.com"})
    assert response.status_code == 429


def test_email_otp_disabled_returns_404_without_creating_code(client, monkeypatch):
    monkeypatch.setenv("EMAIL_OTP_ENABLED", "false")
    get_settings.cache_clear()
    monkeypatch.setattr(
        auth_module,
        "get_email_sender",
        lambda: lambda email, code: (_ for _ in ()).throw(AssertionError("sender should not be called")),
    )
    try:
        requested = client.post("/api/v1/auth/email-otp/request", json={"email": "otp@example.com"})
        verified = client.post(
            "/api/v1/auth/email-otp/verify",
            json={"email": "otp@example.com", "code": "123456"},
        )
        with TestingSessionLocal() as db:
            otp_count = db.query(EmailOTPCode).count()
    finally:
        get_settings.cache_clear()

    assert requested.status_code == 404
    assert requested.json()["error"]["code"] == "not_found"
    assert verified.status_code == 404
    assert verified.json()["error"]["code"] == "not_found"
    assert otp_count == 0


def test_register_device_upserts_user_token(client):
    headers, _ = register_and_auth(client)

    first = client.post(
        "/api/v1/devices",
        headers=headers,
        json={"platform": "ios", "token": "device-token", "app_version": "1.1.0"},
    )
    second = client.post(
        "/api/v1/devices",
        headers=headers,
        json={"platform": "ios", "token": "device-token", "app_version": "1.1.1"},
    )

    assert first.status_code == 204, first.text
    assert second.status_code == 204, second.text
    db = TestingSessionLocal()
    try:
        rows = db.query(DeviceToken).all()
        assert len(rows) == 1
        assert rows[0].app_version == "1.1.1"
        assert rows[0].last_seen_at is not None
    finally:
        db.close()


def test_otp_per_email_throttle_blocks_6th_request_within_hour(client, monkeypatch):
    """P0-4 (#16): same email cannot request more than the configured cap per hour."""

    monkeypatch.setattr(auth_module, "get_email_sender", lambda: lambda email, code: None)
    # Default config caps at 5/hour. Five requests must succeed, the 6th must 429.
    # Use a unique email so the slowapi per-IP limiter (5/minute on this route)
    # doesn't shadow what we're actually testing here — we issue from different
    # client IPs is impossible in TestClient, so we instead pull the throttle
    # cap down to 2 to keep us under the slowapi 5/minute window.
    monkeypatch.setenv("RATE_LIMIT_OTP_PER_EMAIL_PER_HOUR", "2")
    get_settings.cache_clear()
    try:
        first = client.post(
            "/api/v1/auth/email-otp/request", json={"email": "throttle@example.com"}
        )
        second = client.post(
            "/api/v1/auth/email-otp/request", json={"email": "throttle@example.com"}
        )
        third = client.post(
            "/api/v1/auth/email-otp/request", json={"email": "throttle@example.com"}
        )
    finally:
        get_settings.cache_clear()

    assert first.status_code == 204, first.text
    assert second.status_code == 204, second.text
    assert third.status_code == 429, third.text
    assert third.json()["error"]["code"] == "rate_limited"


def test_otp_cleanup_removes_expired_rows():
    """P0-4: cleanup_expired() deletes rows whose expires_at is older than 7d."""

    with TestingSessionLocal() as db:
        now = datetime.now(timezone.utc)
        # Old expired row (10 days old) — should be deleted.
        db.add(
            EmailOTPCode(
                email="stale@example.com",
                code_hash="x" * 64,
                expires_at=now - timedelta(days=10),
            )
        )
        # Recent expired row (1 day old) — must survive (cutoff is 7 days).
        db.add(
            EmailOTPCode(
                email="recent@example.com",
                code_hash="y" * 64,
                expires_at=now - timedelta(days=1),
            )
        )
        # Live row — must survive.
        db.add(
            EmailOTPCode(
                email="live@example.com",
                code_hash="z" * 64,
                expires_at=now + timedelta(minutes=10),
            )
        )
        db.commit()

        deleted = email_otp_service.cleanup_expired(db, older_than_days=7)
        remaining = {row.email for row in db.query(EmailOTPCode).all()}

    assert deleted == 1
    assert remaining == {"recent@example.com", "live@example.com"}


# ---------------------------------------------------------------------------
# v1.2.4 P1: device-logout hardening + device-session refresh chain
# ---------------------------------------------------------------------------

_DEVICE_ID = "device-uuid-fixture-1"


def _seed_device_session(client) -> tuple[dict, str]:
    """Register a user, then directly issue a device session for them.

    Returns ({headers, user_id, device_id}, plaintext_refresh_token).
    """
    headers, _ = register_and_auth(client)
    user_id = client.get("/api/v1/me", headers=headers).json()["id"]
    with TestingSessionLocal() as db:
        user = db.scalar(
            select(User).where(User.id == user_id)
        )
        issued = device_session_service.issue(
            db,
            user=user,
            device_id=_DEVICE_ID,
            device_name="Test Mac",
            platform="macos",
        )
        refresh_token = issued.plaintext_refresh_token
    return {"headers": headers, "user_id": user_id, "device_id": _DEVICE_ID}, refresh_token


def test_device_logout_requires_auth_returns_401_when_no_token(client):
    """P1-1 (#6): device-logout without any auth must 401."""
    _, _ = _seed_device_session(client)

    response = client.post(
        "/api/v1/auth/device-logout",
        json={"device_id": _DEVICE_ID},
    )

    assert response.status_code == 401, response.text
    assert response.json()["error"]["code"] == "unauthorized"

    # Session must still be live.
    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is None


def test_device_logout_with_access_jwt_succeeds(client):
    """P1-1 (#6): valid access JWT belonging to the session owner unlocks revoke."""
    info, _refresh = _seed_device_session(client)

    response = client.post(
        "/api/v1/auth/device-logout",
        headers=info["headers"],
        json={"device_id": _DEVICE_ID},
    )

    assert response.status_code == 204, response.text
    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is not None


def test_device_logout_with_refresh_token_succeeds(client):
    """P1-1 (#6): caller can also authenticate via body.refresh_token."""
    _, refresh_token = _seed_device_session(client)

    response = client.post(
        "/api/v1/auth/device-logout",
        json={"device_id": _DEVICE_ID, "refresh_token": refresh_token},
    )

    assert response.status_code == 204, response.text
    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is not None


def test_device_logout_with_wrong_refresh_token_returns_401(client):
    """P1-1 (#6): mismatched refresh_token must be rejected with 401."""
    _, _ = _seed_device_session(client)

    response = client.post(
        "/api/v1/auth/device-logout",
        json={"device_id": _DEVICE_ID, "refresh_token": "totally-wrong"},
    )

    assert response.status_code == 401, response.text
    assert response.json()["error"]["code"] == "unauthorized"

    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is None


def test_issue_after_revoke_creates_fresh_row_or_resets_cleanly(client):
    """P1-1 (#25): issue() must NOT silently un-revoke a dead session.

    The new row must have a fresh refresh_token_hash (the old token must
    not still be valid) and revoked_at must be NULL.
    """
    info, refresh_token = _seed_device_session(client)
    user_id = info["user_id"]

    # 1) Revoke the session.
    with TestingSessionLocal() as db:
        device_session_service.revoke(db, device_id=_DEVICE_ID)

    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is not None
        revoked_row_id = session.id

    # 2) Issue again with the same device_id — must produce a clean row.
    with TestingSessionLocal() as db:
        user = db.scalar(
            select(User).where(User.id == user_id)
        )
        reissued = device_session_service.issue(
            db,
            user=user,
            device_id=_DEVICE_ID,
            device_name="Test Mac",
            platform="macos",
        )
        new_refresh = reissued.plaintext_refresh_token

    with TestingSessionLocal() as db:
        session = db.scalar(
            select(DeviceSession).where(DeviceSession.device_id == _DEVICE_ID)
        )
        assert session is not None
        assert session.revoked_at is None, "Re-issued session must NOT carry old revoked_at"
        # Either the row id changed (delete + insert) or, if reused, hashes differ.
        # We accept both; the contract is "clean row with new token".
        assert session.id != revoked_row_id or session.refresh_token_hash != device_session_service._hash(refresh_token)

    # 3) Old refresh token must NOT rotate the new session.
    response = client.post(
        "/api/v1/auth/device-refresh",
        json={"device_id": _DEVICE_ID, "refresh_token": refresh_token},
    )
    assert response.status_code == 401, response.text

    # 4) New refresh token DOES rotate (sanity).
    response = client.post(
        "/api/v1/auth/device-refresh",
        json={"device_id": _DEVICE_ID, "refresh_token": new_refresh},
    )
    assert response.status_code == 200, response.text


# ---------------------------------------------------------------------------
# v1.2.4 P2: /auth/refresh rotation + jti blacklist (#19)
# ---------------------------------------------------------------------------


def test_refresh_rotates_jti_and_invalidates_old_token(client):
    """P2-3 (#19): refresh must hand back a NEW refresh_token and the OLD
    one must immediately stop working (replay attack mitigation)."""

    headers, _ = register_and_auth(client)
    # register_and_auth already issued a refresh token; pull it out via login
    # (cleaner than rummaging in the response of register_and_auth itself).
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "password123"},
    )
    assert login.status_code == 200, login.text
    first_refresh = login.json()["refresh_token"]
    assert first_refresh, "issue_tokens must return a refresh_token"

    rotated = client.post("/api/v1/auth/refresh", json={"refresh_token": first_refresh})
    assert rotated.status_code == 200, rotated.text
    second_refresh = rotated.json()["refresh_token"]
    assert second_refresh and second_refresh != first_refresh, (
        "rotation must mint a fresh refresh_token"
    )

    # Replaying the original token must fail.
    replay = client.post("/api/v1/auth/refresh", json={"refresh_token": first_refresh})
    assert replay.status_code == 401, replay.text
    assert replay.json()["error"]["code"] == "unauthorized"

    # The new token still works.
    rotated_again = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": second_refresh}
    )
    assert rotated_again.status_code == 200, rotated_again.text
    third_refresh = rotated_again.json()["refresh_token"]
    assert third_refresh and third_refresh != second_refresh


def test_refresh_revoked_jti_returns_401(client):
    """P2-3 (#19): a jti whose row was explicitly revoked must 401."""

    register_and_auth(client)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "password123"},
    )
    assert login.status_code == 200, login.text
    refresh_token = login.json()["refresh_token"]

    # Decode the jti out of the token (test-side: we know the signing key).
    from app.core.security import decode_token

    decoded = decode_token(refresh_token, expected_type="refresh")
    assert decoded and decoded.get("jti")
    jti = decoded["jti"]

    with TestingSessionLocal() as db:
        row = db.scalar(select(RefreshTokenJTI).where(RefreshTokenJTI.jti == jti))
        assert row is not None, "issue_tokens must persist a jti row"
        row.revoked_at = datetime.now(timezone.utc)
        db.commit()

    response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert response.status_code == 401, response.text
    assert response.json()["error"]["code"] == "unauthorized"


def test_refresh_expired_jti_returns_401(client):
    """P2-3 (#19): expired jti row must 401 even if JWT signature still verifies."""

    register_and_auth(client)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "password123"},
    )
    assert login.status_code == 200, login.text
    refresh_token = login.json()["refresh_token"]

    from app.core.security import decode_token

    decoded = decode_token(refresh_token, expected_type="refresh")
    jti = decoded["jti"]

    with TestingSessionLocal() as db:
        row = db.scalar(select(RefreshTokenJTI).where(RefreshTokenJTI.jti == jti))
        assert row is not None
        # Force the row to be already-expired by 1 minute.
        row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()

    response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert response.status_code == 401, response.text
    assert response.json()["error"]["code"] == "unauthorized"


def test_refresh_missing_jti_payload_returns_401(client, monkeypatch):
    """P2-3 (#19): a refresh token minted without a jti claim (legacy v1.2.3
    survivor) must NOT be accepted — otherwise the blacklist gives no security."""

    from app.core.security import create_token

    register_and_auth(client)
    me_id = client.get(
        "/api/v1/me",
        headers={"Authorization": "Bearer " + client.post(
            "/api/v1/auth/login",
            json={"email": "user@example.com", "password": "password123"},
        ).json()["access_token"]},
    ).json()["id"]

    legacy_token = create_token(
        subject=me_id,
        token_type="refresh",
        expires_delta=timedelta(days=30),
    )  # no extra_claims => no jti
    response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": legacy_token}
    )
    assert response.status_code == 401, response.text
    assert response.json()["error"]["code"] == "unauthorized"


# ---------------------------------------------------------------------------
# v1.2.4 P2: /auth/register lockdown (#5)
# ---------------------------------------------------------------------------


def test_register_in_prod_without_invite_returns_404(client, monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("REGISTER_INVITE_TOKEN", "")
    get_settings.cache_clear()
    try:
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "blocked@example.com",
                "password": "password123",
                "display_name": "Blocked",
                "timezone": "America/New_York",
            },
        )
    finally:
        get_settings.cache_clear()

    assert response.status_code == 404, response.text
    assert response.json()["error"]["code"] == "not_found"

    # No user must have been created.
    with TestingSessionLocal() as db:
        row = db.scalar(select(User).where(User.email == "blocked@example.com"))
        assert row is None


def test_register_in_prod_with_invite_succeeds(client, monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("REGISTER_INVITE_TOKEN", "super-secret-invite")
    get_settings.cache_clear()
    try:
        response = client.post(
            "/api/v1/auth/register",
            headers={"X-Invite-Token": "super-secret-invite"},
            json={
                "email": "invited@example.com",
                "password": "password123",
                "display_name": "Invited",
                "timezone": "America/New_York",
            },
        )
        # Wrong / missing invite must 401 (not 404 — invite token is configured).
        wrong = client.post(
            "/api/v1/auth/register",
            headers={"X-Invite-Token": "wrong-token"},
            json={
                "email": "rejected@example.com",
                "password": "password123",
                "display_name": "Rejected",
                "timezone": "America/New_York",
            },
        )
    finally:
        get_settings.cache_clear()

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["access_token"] and body["refresh_token"]
    assert wrong.status_code == 401, wrong.text
    assert wrong.json()["error"]["code"] == "unauthorized"


def test_db_check_rejects_overlong_task_title(client):
    headers, spaces = register_and_auth(client)
    user_id = client.get("/api/v1/me", headers=headers).json()["id"]
    db = TestingSessionLocal()
    try:
        db.add(
            Task(
                user_id=user_id,
                space_id=spaces["personal"]["id"],
                title="x" * 201,
                priority="medium",
            )
        )
        try:
            db.flush()
            raise AssertionError("Expected DB check constraint to reject overlong title.")
        except IntegrityError:
            db.rollback()
    finally:
        db.close()
