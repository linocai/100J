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

