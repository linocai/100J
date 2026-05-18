import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.database import get_db
from app.main import create_app
from tests.conftest import TestingSessionLocal


def make_test_client():
    app = create_app()

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


def test_local_owner_can_use_core_api_without_token(client):
    me = client.get("/api/v1/me")
    assert me.status_code == 200, me.text
    assert me.json()["email"] == "owner@100j.app"
    assert me.json()["timezone"] == "Asia/Shanghai"

    spaces_response = client.get("/api/v1/spaces")
    assert spaces_response.status_code == 200, spaces_response.text
    spaces = {space["type"]: space for space in spaces_response.json()["items"]}
    assert set(spaces) == {"personal", "company"}

    task = client.post(
        "/api/v1/tasks",
        json={"space_id": spaces["personal"]["id"], "title": "本机 owner 待办"},
    )
    assert task.status_code == 201, task.text

    note = client.post(
        "/api/v1/notes",
        json={"space_id": spaces["personal"]["id"], "body": "本机 owner 备忘"},
    )
    assert note.status_code == 201, note.text

    project = client.post(
        "/api/v1/projects",
        json={"space_id": spaces["company"]["id"], "name": "本机 owner 项目"},
    )
    assert project.status_code == 201, project.text

    calendar_item = client.post(
        "/api/v1/calendar-items",
        json={
            "space_id": spaces["personal"]["id"],
            "title": "本机 owner 日程",
            "type": "reminder",
            "all_day": True,
            "start_date": "2026-05-18",
        },
    )
    assert calendar_item.status_code == 201, calendar_item.text


def test_jwt_mode_requires_token(monkeypatch):
    monkeypatch.setenv("AUTH_MODE", "jwt")
    get_settings.cache_clear()
    try:
        jwt_client = make_test_client()
        response = jwt_client.get("/api/v1/me")
        assert response.status_code == 401
    finally:
        get_settings.cache_clear()


def test_production_rejects_local_owner(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("AUTH_MODE", "local_owner")
    get_settings.cache_clear()
    try:
        with pytest.raises(RuntimeError, match="local_owner"):
            create_app()
    finally:
        get_settings.cache_clear()


def test_production_rejects_default_secrets(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("AUTH_MODE", "jwt")
    get_settings.cache_clear()
    try:
        with pytest.raises(RuntimeError, match="JWT_SECRET_KEY"):
            create_app()
    finally:
        get_settings.cache_clear()


def test_pending_confirmation_expires(monkeypatch):
    monkeypatch.setenv("PENDING_CONFIRMATION_EXPIRE_MINUTES", "0")
    get_settings.cache_clear()
    try:
        local_client = make_test_client()
        spaces = {space["type"]: space for space in local_client.get("/api/v1/spaces").json()["items"]}
        item = local_client.post(
            "/api/v1/calendar-items",
            json={
                "space_id": spaces["personal"]["id"],
                "title": "需要确认的日程",
                "type": "appointment",
                "all_day": False,
                "start_at": "2026-06-01T09:00:00+08:00",
            },
        ).json()

        response = local_client.post(
            "/api/v1/agent/commands",
            json={
                "command": "update_calendar_item",
                "arguments": {
                    "calendar_item_id": item["id"],
                    "start_at": "2026-06-01T10:00:00+08:00",
                },
            },
        )
        assert response.status_code == 200, response.text
        token = response.json()["confirmation_token"]

        confirmed = local_client.post(
            "/api/v1/agent/commands/confirm",
            json={"confirmation_token": token},
        )
        assert confirmed.status_code == 404
        assert confirmed.json()["error"]["message"] == "Confirmation token expired."
    finally:
        get_settings.cache_clear()
