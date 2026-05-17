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

## v1 API Areas

- Auth: `/api/v1/auth/*`
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

