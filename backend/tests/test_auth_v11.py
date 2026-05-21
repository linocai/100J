from sqlalchemy.exc import IntegrityError

import app.api.v1.auth as auth_module
import app.services.apple_auth_service as apple_auth_service
from app.models import DeviceToken, Task
from tests.conftest import TestingSessionLocal, register_and_auth


def test_apple_signin_creates_default_spaces_and_reuses_sub(client, monkeypatch):
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {
            "sub": "apple-sub-1",
            "email": "apple@example.com",
        },
    )

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


def test_apple_signin_binds_existing_email_user(client, monkeypatch):
    headers, _ = register_and_auth(client)
    original_id = client.get("/api/v1/me", headers=headers).json()["id"]
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {
            "sub": "apple-sub-existing",
            "email": "user@example.com",
        },
    )

    response = client.post(
        "/api/v1/auth/apple",
        json={"id_token": "token", "bundle_id": "top.linotsai.app.PersonalAffairs"},
    )

    assert response.status_code == 200, response.text
    apple_headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
    assert client.get("/api/v1/me", headers=apple_headers).json()["id"] == original_id


def test_apple_signin_rejects_unknown_audience(client, monkeypatch):
    monkeypatch.setattr(
        apple_auth_service,
        "_verify_apple_id_token",
        lambda id_token, expected_audience: {"sub": "apple-sub-2"},
    )

    response = client.post(
        "/api/v1/auth/apple",
        json={"id_token": "token", "bundle_id": "com.example.other"},
    )

    assert response.status_code == 401


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
