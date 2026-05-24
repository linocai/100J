from datetime import date

from sqlalchemy.dialects import postgresql

from app.services import calendar_service
from tests.conftest import register_and_auth


def test_personal_task_cannot_bind_project(client):
    headers, spaces = register_and_auth(client)
    company_project = client.post(
        "/api/v1/projects",
        headers=headers,
        json={"space_id": spaces["company"]["id"], "name": "Company Project"},
    ).json()

    response = client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "project_id": company_project["id"],
            "title": "Wrong personal task",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_project_can_only_be_created_in_company_space(client):
    headers, spaces = register_and_auth(client)

    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={"space_id": spaces["personal"]["id"], "name": "Personal Project"},
    )

    assert response.status_code == 422


def test_company_task_can_have_no_project_or_project(client):
    headers, spaces = register_and_auth(client)
    no_project = client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"space_id": spaces["company"]["id"], "project_id": None, "title": "Company loose task"},
    )
    assert no_project.status_code == 201, no_project.text
    assert no_project.json()["project_id"] is None

    project = client.post(
        "/api/v1/projects",
        headers=headers,
        json={"space_id": spaces["company"]["id"], "name": "Company Project"},
    ).json()
    project_task = client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "space_id": spaces["company"]["id"],
            "project_id": project["id"],
            "title": "Project task",
        },
    )
    assert project_task.status_code == 201, project_task.text
    assert project_task.json()["project_id"] == project["id"]


def test_note_can_only_belong_to_personal_space(client):
    headers, spaces = register_and_auth(client)

    response = client.post(
        "/api/v1/notes",
        headers=headers,
        json={"space_id": spaces["company"]["id"], "body": "Company note"},
    )

    assert response.status_code == 422


def test_long_text_payloads_are_rejected(client):
    headers, spaces = register_and_auth(client)

    task = client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Too much task text",
            "description": "x" * 10_001,
        },
    )
    assert task.status_code == 422

    note = client.post(
        "/api/v1/notes",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "body": "x" * 20_001,
        },
    )
    assert note.status_code == 422

    calendar = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Too much calendar text",
            "description": "x" * 10_001,
            "all_day": True,
            "start_date": "2026-08-01",
        },
    )
    assert calendar.status_code == 422


def test_calendar_all_day_and_timed_validation(client):
    headers, spaces = register_and_auth(client)

    all_day = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Subscription expiry",
            "type": "subscription_expiry",
            "all_day": True,
            "start_date": "2026-08-01",
        },
    )
    assert all_day.status_code == 201, all_day.text

    bad_all_day = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Bad all day",
            "type": "subscription_expiry",
            "all_day": True,
            "start_at": "2026-08-01T09:00:00-04:00",
        },
    )
    assert bad_all_day.status_code == 422

    timed = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Appointment",
            "type": "appointment",
            "all_day": False,
            "start_at": "2026-06-01T09:00:00-04:00",
        },
    )
    assert timed.status_code == 201, timed.text

    bad_timed = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Bad timed",
            "type": "appointment",
            "all_day": False,
            "start_date": "2026-06-01",
        },
    )
    assert bad_timed.status_code == 422


def test_calendar_date_window_uses_date_binds_for_postgres(monkeypatch):
    captured = {}

    def capture_paginate(db, statement, limit, cursor):
        captured["compiled"] = statement.compile(dialect=postgresql.dialect())
        return [], None

    monkeypatch.setattr(calendar_service, "paginate", capture_paginate)

    calendar_service.list_calendar_items(
        db=None,
        user_id="user-1",
        space_id="space-1",
        from_date="2026-04-19",
        to_date=date(2026, 11, 15),
    )

    compiled = captured["compiled"]
    assert compiled.params["date_1"] == date(2026, 4, 19)
    assert compiled.params["date_2"] == date(2026, 11, 15)
    assert compiled.binds["date_1"].type.python_type is date
    assert compiled.binds["date_2"].type.python_type is date


def test_calendar_update_switches_from_timed_to_all_day_clears_start_at(client):
    """P4-1 (#4): toggling all_day=True on a previously-timed event must
    clear start_at/end_at server-side instead of 422-ing on stale fields."""
    headers, spaces = register_and_auth(client)
    timed = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Therapy session",
            "type": "appointment",
            "all_day": False,
            "start_at": "2026-06-01T09:00:00-04:00",
            "end_at": "2026-06-01T10:00:00-04:00",
        },
    ).json()

    response = client.patch(
        "/api/v1/calendar-items/{}".format(timed["id"]),
        headers=headers,
        json={"all_day": True, "start_date": "2026-06-01"},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["all_day"] is True
    assert body["start_date"] == "2026-06-01"
    assert body["start_at"] is None
    assert body["end_at"] is None


def test_calendar_update_switches_from_all_day_to_timed_clears_start_date(client):
    """P4-1 (#4): toggling all_day=False must clear start_date/end_date."""
    headers, spaces = register_and_auth(client)
    all_day = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Anniversary",
            "type": "anniversary",
            "all_day": True,
            "start_date": "2026-08-01",
            "end_date": "2026-08-01",
        },
    ).json()

    response = client.patch(
        "/api/v1/calendar-items/{}".format(all_day["id"]),
        headers=headers,
        json={
            "all_day": False,
            "start_at": "2026-08-01T09:00:00-04:00",
            "end_at": "2026-08-01T10:00:00-04:00",
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["all_day"] is False
    assert body["start_date"] is None
    assert body["end_date"] is None
    assert body["start_at"] is not None
    assert body["end_at"] is not None


def test_calendar_update_rejects_end_before_start(client):
    """P4-2 (#22): end < start must 422 for both all-day and timed."""
    headers, spaces = register_and_auth(client)

    bad_all_day = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Bad span all day",
            "type": "anniversary",
            "all_day": True,
            "start_date": "2026-08-05",
            "end_date": "2026-08-01",
        },
    )
    assert bad_all_day.status_code == 422
    assert bad_all_day.json()["error"]["code"] == "validation_error"

    bad_timed = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Bad span timed",
            "type": "appointment",
            "all_day": False,
            "start_at": "2026-08-01T10:00:00-04:00",
            "end_at": "2026-08-01T09:00:00-04:00",
        },
    )
    assert bad_timed.status_code == 422
    assert bad_timed.json()["error"]["code"] == "validation_error"


def test_note_update_rejects_linked_task_from_other_user(client):
    """P4-3 (#23): PATCH /notes/{id} with someone else's task_id must 404
    instead of silently stitching cross-tenant data."""
    headers, spaces = register_and_auth(client)

    # Note belonging to the authenticated user.
    note = client.post(
        "/api/v1/notes",
        headers=headers,
        json={"space_id": spaces["personal"]["id"], "body": "Mine"},
    ).json()

    # A second user with their own personal task.
    other = client.post(
        "/api/v1/auth/register",
        json={
            "email": "other@example.com",
            "password": "password123",
            "display_name": "Other",
            "timezone": "America/New_York",
        },
    )
    assert other.status_code == 201, other.text
    other_headers = {"Authorization": "Bearer {}".format(other.json()["access_token"])}
    other_spaces = client.get("/api/v1/spaces", headers=other_headers).json()["items"]
    other_personal = next(s for s in other_spaces if s["type"] == "personal")
    other_task = client.post(
        "/api/v1/tasks",
        headers=other_headers,
        json={"space_id": other_personal["id"], "title": "Not yours"},
    ).json()

    response = client.patch(
        "/api/v1/notes/{}".format(note["id"]),
        headers=headers,
        json={"linked_task_id": other_task["id"]},
    )
    assert response.status_code == 404, response.text
    assert response.json()["error"]["code"] == "not_found"


def test_note_convert_to_task_keeps_note(client):
    headers, spaces = register_and_auth(client)
    note = client.post(
        "/api/v1/notes",
        headers=headers,
        json={"space_id": spaces["personal"]["id"], "title": "Idea", "body": "Turn this into work"},
    ).json()

    response = client.post(
        "/api/v1/notes/{}/convert-to-task".format(note["id"]),
        headers=headers,
        json={"title": "Process idea", "priority": "medium"},
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["task"]["title"] == "Process idea"
    assert payload["note"]["id"] == note["id"]
    assert payload["note"]["linked_task_id"] == payload["task"]["id"]
