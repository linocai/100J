# Phase 4 Local Test Report

## Status

Automated local verification is complete. Manual macOS and iOS interaction testing is ready for the user.

## Running Backend For Manual Test

The local API is running at:

```text
http://127.0.0.1:8000
```

Runtime files:

```text
database: /tmp/personal_affairs_phase4_api.db
pid: /tmp/personal-affairs-phase4-api.pid
log: /tmp/personal-affairs-phase4-api.log
```

Stop the server:

```bash
kill $(cat /tmp/personal-affairs-phase4-api.pid)
```

Restart with a fresh local database:

```bash
cd backend
rm -f /tmp/personal_affairs_phase4_api.db /tmp/personal-affairs-phase4-api.log /tmp/personal-affairs-phase4-api.pid
DATABASE_URL=sqlite:////tmp/personal_affairs_phase4_api.db .venv/bin/alembic upgrade head
DATABASE_URL=sqlite:////tmp/personal_affairs_phase4_api.db \
JWT_SECRET_KEY=phase4-local-secret \
LLM_KEY_ENCRYPTION_SECRET=phase4-local-32-byte-minimum-secret \
PYTHONPATH=. \
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## Automated Verification Passed

Backend:

```bash
cd backend
.venv/bin/ruff check .
.venv/bin/python -m pytest
DATABASE_URL=sqlite:////tmp/personal_affairs_phase4_migration.db .venv/bin/alembic upgrade head
PYTHONPATH=. DATABASE_URL=sqlite:///:memory: .venv/bin/python -c 'from app.main import app; assert "/api/v1/tasks" in app.openapi()["paths"]'
.venv/bin/python scripts/phase4_smoke.py --base-url http://127.0.0.1:8000
```

Apple:

```bash
cd frontend/apple
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

## API Smoke Coverage

- Health: `/health`, `/api/v1/health`.
- Auth: register, `/me`, refresh token.
- Spaces: default Personal and Company spaces after registration.
- Personal Task: create, complete, reopen.
- Company Project: create.
- Company Task: no-project task and project task.
- Project detail: list project tasks.
- Personal Note: create and convert to task.
- Calendar: create Personal all-day item and Company timed project item.
- Business rules: rejected Personal task with project, Personal project, Company note, invalid all-day calendar, invalid timed calendar.
- Agent: dry run, create task, confirmation-required calendar update, confirm, action logs.

## Manual macOS Checklist

- Log in or register against `http://127.0.0.1:8000/api/v1`.
- Personal Tasks: create, edit, complete, reopen, archive.
- Personal Notes: create, edit, archive, convert to task.
- Company Tasks: create no-project task, create project task, filter by status and project scope.
- Company Projects: create, open detail, inspect project tasks, complete, archive.
- Calendar: verify All view shows Personal and Company items, create all-day and timed items.
- Agent: run dry run, run create task, verify action logs.
- Settings: change API URL, refresh data, logout.

## Manual iOS Checklist

- Build/run `PersonalAffairsApp` on an iOS Simulator.
- Register or log in against `http://127.0.0.1:8000/api/v1`.
- Personal tab: Tasks / Notes segmented control, create, edit, swipe complete/archive.
- Company tab: Tasks / Projects segmented control, no-project and project filters, project detail, project task creation.
- Calendar tab: All / Personal / Company / Project filters, create, edit, delete.
- Agent tab: command, dry run, confirmation token, action logs.
- Settings tab: API base URL, refresh, logout.

## Cross-Client Manual Checks

- Create a task on macOS, refresh iOS, confirm it appears.
- Create a note on iOS, refresh macOS, confirm it appears.
- Create a Company CalendarItem on one client, confirm Calendar All view shows it on the other.
- Use Agent to create a task, refresh both clients, confirm the task and action log are visible.

## Defects

No P0, P1, or P2 defects were found by automated Phase 4 checks. Manual UI testing remains pending.
