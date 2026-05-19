from tests.conftest import register_and_auth


def test_agent_dry_run_validates_create_task_arguments(client):
    headers, _ = register_and_auth(client)

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "create_task",
            "dry_run": True,
            "arguments": {"title": "Missing space"},
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_agent_dry_run_validates_long_text_limits(client):
    headers, spaces = register_and_auth(client)

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "create_task",
            "dry_run": True,
            "arguments": {
                "space_id": spaces["personal"]["id"],
                "title": "Overlong",
                "description": "x" * 10_001,
            },
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_agent_valid_dry_run_does_not_write_action_log(client):
    headers, spaces = register_and_auth(client)

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "create_note",
            "dry_run": True,
            "arguments": {
                "space_id": spaces["personal"]["id"],
                "body": "Capture this idea",
            },
        },
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "dry_run"

    logs = client.get("/api/v1/agent/action-logs", headers=headers)
    assert logs.status_code == 200
    assert logs.json()["items"] == []


def test_agent_validates_before_requesting_confirmation(client):
    headers, _ = register_and_auth(client)

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "update_calendar_item",
            "arguments": {"start_at": "2026-06-01T10:00:00-04:00"},
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert "confirmation_token" not in response.text


def test_agent_create_task_writes_action_log(client):
    headers, spaces = register_and_auth(client)

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "create_task",
            "arguments": {
                "space_id": spaces["personal"]["id"],
                "title": "Agent task",
            },
        },
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "success"

    logs = client.get("/api/v1/agent/action-logs", headers=headers)
    assert logs.status_code == 200
    items = logs.json()["items"]
    assert len(items) == 1
    assert items[0]["action_type"] == "create_task"
    assert items[0]["status"] == "success"


def test_agent_update_calendar_time_requires_confirmation(client):
    headers, spaces = register_and_auth(client)
    item = client.post(
        "/api/v1/calendar-items",
        headers=headers,
        json={
            "space_id": spaces["personal"]["id"],
            "title": "Appointment",
            "type": "appointment",
            "all_day": False,
            "start_at": "2026-06-01T09:00:00-04:00",
        },
    ).json()

    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={
            "command": "update_calendar_item",
            "arguments": {
                "calendar_item_id": item["id"],
                "start_at": "2026-06-01T10:00:00-04:00",
            },
        },
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["status"] == "requires_confirmation"
    assert payload["confirmation_token"]

    confirmed = client.post(
        "/api/v1/agent/commands/confirm",
        headers=headers,
        json={"confirmation_token": payload["confirmation_token"]},
    )
    assert confirmed.status_code == 200, confirmed.text
    assert confirmed.json()["status"] == "success"

    logs = client.get("/api/v1/agent/action-logs", headers=headers).json()["items"]
    statuses = [log["status"] for log in logs]
    assert "requires_confirmation" in statuses
    assert "success" in statuses
