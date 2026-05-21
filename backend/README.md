# Personal Affairs Backend

FastAPI backend for Personal Affairs App v1.

## Local Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
cp .env.example .env
```

Edit `.env` if your local PostgreSQL URL differs from the default.

The default auth mode is `AUTH_MODE=local_owner`. In this mode the API lazily creates one
local owner user plus Personal / Company spaces, and local tools can call APIs without JWT login.
For v1.1 Apple clients, use `AUTH_MODE=jwt` with Sign in with Apple or Email OTP. The
`OWNER_CLOUD_ACCESS_CODE` path is retained only as a self-host/debug rollback channel at
`/api/v1/auth/owner-login`.

## Database

Run migrations:

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

The default development database URL is:

```text
postgresql+psycopg://personal_affairs:personal_affairs@localhost:5432/personal_affairs
```

For quick local smoke tests without PostgreSQL, set:

```bash
export DATABASE_URL=sqlite:///./personal_affairs.db
alembic upgrade head
```

## Run API

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload
```

Health checks:

```text
GET /health
GET /api/v1/health
```

OpenAPI docs:

```text
http://127.0.0.1:8000/docs
```

## Test

```bash
cd backend
source .venv/bin/activate
pytest
```

Tests use in-memory SQLite and do not require a local PostgreSQL server.

## Production Deployment

Production deployment is documented in `../deployment.md`. The HZ cloud deployment uses systemd,
PostgreSQL, `APP_ENV=production`, and `AUTH_MODE=jwt`.

Production secrets must be random and must not use the development defaults:

- `JWT_SECRET_KEY`
- `POSTGRES_PASSWORD`
- `LLM_KEY_ENCRYPTION_SECRET`
- `OWNER_CLOUD_ACCESS_CODE`
- `APPLE_ALLOWED_AUDIENCES`

`LLM_KEY_ENCRYPTION_SECRET` is hashed into the Fernet key material at runtime; use a high-entropy
random value in production, not the example placeholder.

## Phase 4 Local Smoke

With the API running locally, execute:

```bash
cd backend
.venv/bin/python scripts/phase4_smoke.py --base-url http://127.0.0.1:8000
```

The smoke test registers a disposable test user and verifies auth, spaces, tasks, projects, notes, calendar items, business-rule failures, Agent confirmation, action logs, and token refresh. This remains valid while the default local owner mode is enabled because valid bearer tokens still resolve to their token user.

## v1 API Areas

- Auth: `/api/v1/auth/*`
- Devices: `/api/v1/devices`
- Spaces: `/api/v1/spaces`
- Tasks: `/api/v1/tasks`
- Projects: `/api/v1/projects`
- CalendarItems: `/api/v1/calendar-items`
- Notes: `/api/v1/notes`
- Agent: `/api/v1/agent/*`

## Product Rules Enforced By Backend

- Personal tasks cannot have `project_id`.
- Projects can only belong to Company space.
- Company tasks can have `project_id = null`.
- Calendar all-day items require `start_date` and cannot send `start_at` / `end_at`.
- Calendar timed items require `start_at` and cannot send `start_date`.
- Notes can only belong to Personal space.
- Agent write operations create `agent_action_logs`.
- Risky Agent operations require confirmation.
