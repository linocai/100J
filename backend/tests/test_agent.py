from tests.conftest import register_and_auth


AGENT_TOOL_NAMES = {
    "list_tasks",
    "create_task",
    "update_task",
    "complete_task",
    "archive_task",
    "list_projects",
    "create_project",
    "update_project",
    "archive_project",
    "list_calendar_items",
    "create_calendar_item",
    "update_calendar_item",
    "list_notes",
    "create_note",
    "update_note",
    "convert_note_to_task",
}


def run_agent_command(client, headers, command, arguments=None):
    response = client.post(
        "/api/v1/agent/commands",
        headers=headers,
        json={"command": command, "arguments": arguments or {}},
    )
    assert response.status_code == 200, response.text
    return response.json()


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


def test_agent_exposes_and_executes_all_supported_tools(client):
    headers, spaces = register_and_auth(client)

    tools = client.get("/api/v1/agent/tools", headers=headers)
    assert tools.status_code == 200
    assert {tool["name"] for tool in tools.json()["tools"]} == AGENT_TOOL_NAMES

    assert run_agent_command(client, headers, "list_tasks")["status"] == "success"
    task = run_agent_command(
        client,
        headers,
        "create_task",
        {"space_id": spaces["personal"]["id"], "title": "Agent task"},
    )["result"]
    task_id = task["id"]
    assert task["type"] == "task"

    assert run_agent_command(
        client,
        headers,
        "update_task",
        {"task_id": task_id, "title": "Agent task updated", "priority": "high"},
    )["result"]["id"] == task_id
    assert run_agent_command(client, headers, "complete_task", {"task_id": task_id})["result"]["id"] == task_id
    assert run_agent_command(client, headers, "archive_task", {"task_id": task_id})["result"]["id"] == task_id

    assert run_agent_command(client, headers, "list_projects")["status"] == "success"
    project = run_agent_command(
        client,
        headers,
        "create_project",
        {"space_id": spaces["company"]["id"], "name": "Agent Project"},
    )["result"]
    project_id = project["id"]
    assert project["type"] == "project"

    assert run_agent_command(
        client,
        headers,
        "update_project",
        {"project_id": project_id, "description": "Updated by Agent"},
    )["result"]["id"] == project_id

    assert run_agent_command(client, headers, "list_calendar_items")["status"] == "success"
    calendar_item = run_agent_command(
        client,
        headers,
        "create_calendar_item",
        {
            "space_id": spaces["company"]["id"],
            "project_id": project_id,
            "title": "Agent calendar item",
            "type": "appointment",
            "all_day": True,
            "start_date": "2026-06-02",
        },
    )["result"]
    calendar_item_id = calendar_item["id"]
    assert calendar_item["type"] == "calendar_item"

    assert run_agent_command(
        client,
        headers,
        "update_calendar_item",
        {"calendar_item_id": calendar_item_id, "description": "Non-risky update"},
    )["result"]["id"] == calendar_item_id

    assert run_agent_command(client, headers, "list_notes")["status"] == "success"
    note = run_agent_command(
        client,
        headers,
        "create_note",
        {"space_id": spaces["personal"]["id"], "title": "Agent note", "body": "Capture idea"},
    )["result"]
    note_id = note["id"]
    assert note["type"] == "note"

    assert run_agent_command(
        client,
        headers,
        "update_note",
        {"note_id": note_id, "body": "Capture idea, refined"},
    )["result"]["id"] == note_id

    converted = run_agent_command(
        client,
        headers,
        "convert_note_to_task",
        {"note_id": note_id, "title": "Turn note into task", "priority": "medium"},
    )["result"]
    assert converted["type"] == "task"
    assert converted["note_id"] == note_id

    pending = run_agent_command(client, headers, "archive_project", {"project_id": project_id})
    assert pending["status"] == "requires_confirmation"
    assert pending["confirmation_token"]
    confirmed = client.post(
        "/api/v1/agent/commands/confirm",
        headers=headers,
        json={"confirmation_token": pending["confirmation_token"]},
    )
    assert confirmed.status_code == 200, confirmed.text
    assert confirmed.json()["result"]["id"] == project_id

    logs = client.get("/api/v1/agent/action-logs", headers=headers).json()["items"]
    logged_actions = {log["action_type"] for log in logs}
    assert AGENT_TOOL_NAMES - {"list_tasks", "list_projects", "list_calendar_items", "list_notes"} <= logged_actions


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
