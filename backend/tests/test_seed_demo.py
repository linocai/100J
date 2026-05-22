from datetime import datetime, timezone

from sqlalchemy import select

from app.core.config import get_settings
from app.models import CalendarItem, Space, Task
from tests.conftest import TestingSessionLocal, register_and_auth


def test_seed_demo_creates_fixed_data_and_is_idempotent(client):
    headers, _ = register_and_auth(client)

    first = client.post("/api/v1/me/seed-demo", headers=headers)
    assert first.status_code == 200, first.text
    first_body = first.json()
    assert len(first_body["tasks"]) == 5
    assert len(first_body["calendar_items"]) == 2
    assert first_body["created"] == {"tasks": 5, "calendar_items": 2}
    assert {task["source"] for task in first_body["tasks"]} == {"seed_demo"}
    assert {item["source"] for item in first_body["calendar_items"]} == {"seed_demo"}

    second = client.post("/api/v1/me/seed-demo", headers=headers)
    assert second.status_code == 200, second.text
    second_body = second.json()
    assert len(second_body["tasks"]) == 5
    assert len(second_body["calendar_items"]) == 2
    assert second_body["created"] == {"tasks": 0, "calendar_items": 0}
    assert {task["id"] for task in second_body["tasks"]} == {task["id"] for task in first_body["tasks"]}

def test_seed_demo_requires_authentication(client, monkeypatch):
    monkeypatch.setenv("AUTH_MODE", "jwt")
    get_settings.cache_clear()
    try:
        response = client.post("/api/v1/me/seed-demo")
    finally:
        get_settings.cache_clear()

    assert response.status_code == 401


def test_seed_demo_requires_default_spaces(client):
    headers, _ = register_and_auth(client)
    with TestingSessionLocal() as db:
        for space in db.scalars(select(Space)).all():
            space.deleted_at = datetime.now(timezone.utc)
        db.commit()

    response = client.post("/api/v1/me/seed-demo", headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "missing_spaces"


def test_seed_demo_persists_expected_counts(client):
    headers, _ = register_and_auth(client)

    response = client.post("/api/v1/me/seed-demo", headers=headers)
    assert response.status_code == 200, response.text

    with TestingSessionLocal() as db:
        tasks = db.scalars(select(Task).where(Task.source == "seed_demo")).all()
        calendar_items = db.scalars(select(CalendarItem).where(CalendarItem.source == "seed_demo")).all()
    assert len(tasks) == 5
    assert len(calendar_items) == 2
