import argparse
import time

import httpx


PASSWORD = "Phase4-pass-123"


def expect(response: httpx.Response, status: int, label: str):
    if response.status_code != status:
        raise AssertionError(
            f"{label}: expected {status}, got {response.status_code}: {response.text}"
        )
    return response.json() if response.content else None


def main() -> None:
    parser = argparse.ArgumentParser(description="Phase 4 local API smoke test.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    api_url = f"{base_url}/api/v1"
    email = f"phase4_{int(time.time())}@example.com"

    with httpx.Client(timeout=10.0) as client:
        expect(client.get(f"{base_url}/health"), 200, "root health")
        expect(client.get(f"{api_url}/health"), 200, "api health")

        tokens = expect(
            client.post(
                f"{api_url}/auth/register",
                json={
                    "email": email,
                    "password": PASSWORD,
                    "display_name": "Phase 4 Tester",
                    "timezone": "Asia/Shanghai",
                },
            ),
            201,
            "register",
        )
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        refresh_token = tokens["refresh_token"]

        me = expect(client.get(f"{api_url}/me", headers=headers), 200, "me")
        assert me["email"] == email

        spaces_payload = expect(client.get(f"{api_url}/spaces", headers=headers), 200, "spaces")
        spaces = {space["type"]: space for space in spaces_payload["items"]}
        assert {"personal", "company"}.issubset(spaces)
        personal_id = spaces["personal"]["id"]
        company_id = spaces["company"]["id"]

        personal_task = expect(
            client.post(
                f"{api_url}/tasks",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "title": "Phase4 personal task",
                    "priority": "medium",
                    "due_date": "2026-05-20",
                },
            ),
            201,
            "create personal task",
        )
        expect(
            client.post(f"{api_url}/tasks/{personal_task['id']}/complete", headers=headers),
            200,
            "complete personal task",
        )
        expect(
            client.post(f"{api_url}/tasks/{personal_task['id']}/reopen", headers=headers),
            200,
            "reopen personal task",
        )

        project = expect(
            client.post(
                f"{api_url}/projects",
                headers=headers,
                json={
                    "space_id": company_id,
                    "name": "Phase4 company project",
                    "target_date": "2026-06-30",
                },
            ),
            201,
            "create company project",
        )
        company_loose_task = expect(
            client.post(
                f"{api_url}/tasks",
                headers=headers,
                json={
                    "space_id": company_id,
                    "project_id": None,
                    "title": "Phase4 no-project company task",
                },
            ),
            201,
            "create no-project company task",
        )
        company_project_task = expect(
            client.post(
                f"{api_url}/tasks",
                headers=headers,
                json={
                    "space_id": company_id,
                    "project_id": project["id"],
                    "title": "Phase4 project task",
                    "priority": "high",
                },
            ),
            201,
            "create company project task",
        )
        project_tasks = expect(
            client.get(f"{api_url}/projects/{project['id']}/tasks", headers=headers),
            200,
            "list project tasks",
        )
        assert any(item["id"] == company_project_task["id"] for item in project_tasks["items"])

        note = expect(
            client.post(
                f"{api_url}/notes",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "title": "Phase4 idea",
                    "body": "Convert this into a task.",
                    "type": "idea",
                },
            ),
            201,
            "create personal note",
        )
        converted = expect(
            client.post(
                f"{api_url}/notes/{note['id']}/convert-to-task",
                headers=headers,
                json={"title": "Phase4 converted task", "priority": "medium"},
            ),
            200,
            "convert note to task",
        )
        assert converted["note"]["linked_task_id"] == converted["task"]["id"]

        personal_calendar = expect(
            client.post(
                f"{api_url}/calendar-items",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "title": "Phase4 personal subscription",
                    "type": "subscription_expiry",
                    "all_day": True,
                    "start_date": "2026-05-21",
                    "recurrence": "yearly",
                },
            ),
            201,
            "create personal calendar item",
        )
        company_calendar = expect(
            client.post(
                f"{api_url}/calendar-items",
                headers=headers,
                json={
                    "space_id": company_id,
                    "project_id": project["id"],
                    "title": "Phase4 company appointment",
                    "type": "appointment",
                    "all_day": False,
                    "start_at": "2026-05-22T10:00:00+08:00",
                    "timezone": "Asia/Shanghai",
                },
            ),
            201,
            "create company calendar item",
        )
        personal_calendar_list = expect(
            client.get(f"{api_url}/calendar-items", headers=headers, params={"space_id": personal_id}),
            200,
            "list personal calendar",
        )
        company_calendar_list = expect(
            client.get(f"{api_url}/calendar-items", headers=headers, params={"space_id": company_id}),
            200,
            "list company calendar",
        )
        assert any(item["id"] == personal_calendar["id"] for item in personal_calendar_list["items"])
        assert any(item["id"] == company_calendar["id"] for item in company_calendar_list["items"])

        expect(
            client.post(
                f"{api_url}/tasks",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "project_id": project["id"],
                    "title": "Invalid personal project task",
                },
            ),
            422,
            "reject personal task project binding",
        )
        expect(
            client.post(
                f"{api_url}/projects",
                headers=headers,
                json={"space_id": personal_id, "name": "Invalid personal project"},
            ),
            422,
            "reject personal project",
        )
        expect(
            client.post(
                f"{api_url}/notes",
                headers=headers,
                json={"space_id": company_id, "body": "Invalid company note"},
            ),
            422,
            "reject company note",
        )
        expect(
            client.post(
                f"{api_url}/calendar-items",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "title": "Invalid all day",
                    "type": "reminder",
                    "all_day": True,
                    "start_at": "2026-05-22T10:00:00+08:00",
                },
            ),
            422,
            "reject bad all-day calendar",
        )
        expect(
            client.post(
                f"{api_url}/calendar-items",
                headers=headers,
                json={
                    "space_id": personal_id,
                    "title": "Invalid timed",
                    "type": "appointment",
                    "all_day": False,
                    "start_date": "2026-05-22",
                },
            ),
            422,
            "reject bad timed calendar",
        )

        agent_dry_run = expect(
            client.post(
                f"{api_url}/agent/commands",
                headers=headers,
                json={
                    "command": "create_task",
                    "arguments": {"space_id": personal_id, "title": "Dry run task"},
                    "dry_run": True,
                },
            ),
            200,
            "agent dry run",
        )
        assert agent_dry_run["status"] == "dry_run"

        agent_create = expect(
            client.post(
                f"{api_url}/agent/commands",
                headers=headers,
                json={
                    "command": "create_task",
                    "arguments": {"space_id": personal_id, "title": "Phase4 agent task"},
                },
            ),
            200,
            "agent create task",
        )
        assert agent_create["status"] == "success"

        agent_update = expect(
            client.post(
                f"{api_url}/agent/commands",
                headers=headers,
                json={
                    "command": "update_calendar_item",
                    "arguments": {
                        "calendar_item_id": company_calendar["id"],
                        "start_at": "2026-05-22T11:00:00+08:00",
                    },
                },
            ),
            200,
            "agent update calendar requires confirmation",
        )
        assert agent_update["status"] == "requires_confirmation"
        confirmed = expect(
            client.post(
                f"{api_url}/agent/commands/confirm",
                headers=headers,
                json={"confirmation_token": agent_update["confirmation_token"]},
            ),
            200,
            "agent confirm calendar update",
        )
        assert confirmed["status"] == "success"

        logs = expect(client.get(f"{api_url}/agent/action-logs", headers=headers), 200, "agent logs")
        assert any(
            log["action_type"] == "create_task" and log["status"] == "success"
            for log in logs["items"]
        )
        assert any(
            log["action_type"] == "update_calendar_item"
            and log["status"] == "requires_confirmation"
            for log in logs["items"]
        )
        assert any(
            log["action_type"] == "update_calendar_item" and log["status"] == "success"
            for log in logs["items"]
        )

        refreshed = expect(
            client.post(f"{api_url}/auth/refresh", json={"refresh_token": refresh_token}),
            200,
            "refresh token",
        )
        headers2 = {"Authorization": f"Bearer {refreshed['access_token']}"}
        expect(client.get(f"{api_url}/me", headers=headers2), 200, "me after refresh")

    print("phase4 smoke ok")
    print(f"test_user={email}")
    print(f"test_password={PASSWORD}")
    print(f"personal_space={personal_id}")
    print(f"company_space={company_id}")
    print(f"project={project['id']}")
    print(f"company_loose_task={company_loose_task['id']}")


if __name__ == "__main__":
    main()
