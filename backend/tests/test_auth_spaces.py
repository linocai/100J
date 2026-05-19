from tests.conftest import register_and_auth
from app.core.config import get_settings


def test_register_creates_default_spaces(client):
    headers, spaces = register_and_auth(client)

    assert "personal" in spaces
    assert "company" in spaces
    assert spaces["personal"]["name"] == "Personal"
    assert spaces["company"]["name"] == "Company"

    me = client.get("/api/v1/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "user@example.com"


def test_owner_login_uses_single_cloud_owner(client, monkeypatch):
    monkeypatch.setenv("OWNER_CLOUD_ACCESS_CODE", "owner-code-123")
    get_settings.cache_clear()
    try:
        response = client.post(
            "/api/v1/auth/owner-login",
            json={"access_code": "owner-code-123"},
        )
        assert response.status_code == 200, response.text
        token = response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        me = client.get("/api/v1/me", headers=headers)
        assert me.status_code == 200, me.text
        assert me.json()["email"] == "owner@100j.app"

        spaces = client.get("/api/v1/spaces", headers=headers)
        assert spaces.status_code == 200, spaces.text
        by_type = {space["type"]: space for space in spaces.json()["items"]}
        assert set(by_type) == {"personal", "company"}
    finally:
        get_settings.cache_clear()


def test_owner_login_rejects_invalid_code(client, monkeypatch):
    monkeypatch.setenv("OWNER_CLOUD_ACCESS_CODE", "owner-code-123")
    get_settings.cache_clear()
    try:
        response = client.post(
            "/api/v1/auth/owner-login",
            json={"access_code": "wrong-code"},
        )
        assert response.status_code == 401
    finally:
        get_settings.cache_clear()
