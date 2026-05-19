# 100J Deployment

This project deploys the FastAPI backend to the HZ cloud server and exposes it through Nginx at:

```text
https://100j.linotsai.top
```

Domain names are case-insensitive, so this is the deployment target for `100J.linotsai.top`.

## Architecture

- Server: `hz` / Alibaba Cloud ECS / Ubuntu 24.04
- SSH user: `deploy`
- App directory: `/opt/100j/current`
- Env file: `/opt/100j/env/100j.env`
- Runtime: Docker Compose
- API container: FastAPI + Alembic migrations
- DB container: PostgreSQL 16, Docker volume `100j-postgres-data`
- Local server port: `127.0.0.1:8020`
- Public ingress: Nginx HTTPS reverse proxy

## Production Environment

The server env file is created by `scripts/deploy-hz.sh` if missing. It must stay mode `600` and must not be committed.

Required keys:

```text
APP_ENV=production
AUTH_MODE=jwt
DATABASE_URL
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
JWT_SECRET_KEY
JWT_ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES
REFRESH_TOKEN_EXPIRE_DAYS
LLM_KEY_ENCRYPTION_SECRET
PENDING_CONFIRMATION_EXPIRE_MINUTES
CORS_ORIGINS=https://100j.linotsai.top
```

Use random production secrets for `JWT_SECRET_KEY`, `POSTGRES_PASSWORD`, and `LLM_KEY_ENCRYPTION_SECRET`.

## Local Release Checks

Run before deploying:

```bash
cd backend
.venv/bin/ruff check .
.venv/bin/python -m pytest

cd ../frontend/apple
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

## Deploy

From the repo root:

```bash
scripts/deploy-hz.sh
```

The script rsyncs backend deployment files to `/opt/100j/current`, creates `/opt/100j/env/100j.env` if missing, rebuilds the Compose stack, runs Alembic migrations on container start, and checks local health.

## Nginx Reverse Proxy

Create `/etc/nginx/sites-available/100j` on the server:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name 100j.linotsai.top;

    location / {
        proxy_pass http://127.0.0.1:8020;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and test:

```bash
sudo ln -sf /etc/nginx/sites-available/100j /etc/nginx/sites-enabled/100j
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d 100j.linotsai.top --redirect
```

## Verification

```bash
curl -fsS http://127.0.0.1:8020/health
curl -fsS https://100j.linotsai.top/health
curl -fsS https://100j.linotsai.top/api/v1/health
cd backend
.venv/bin/python scripts/phase4_smoke.py --base-url https://100j.linotsai.top --env prod
```

The smoke test registers a disposable user and verifies spaces, CRUD paths, Agent confirmation, action logs, and token refresh.

## Operations

```bash
ssh deploy@118.178.122.194
cd /opt/100j/current
ONEJ_ENV_FILE=/opt/100j/env/100j.env ONEJ_API_PORT=8020 docker compose --env-file /opt/100j/env/100j.env ps
ONEJ_ENV_FILE=/opt/100j/env/100j.env ONEJ_API_PORT=8020 docker compose --env-file /opt/100j/env/100j.env logs --tail=100 api
ONEJ_ENV_FILE=/opt/100j/env/100j.env ONEJ_API_PORT=8020 docker compose --env-file /opt/100j/env/100j.env logs --tail=100 db
```

Restart:

```bash
cd /opt/100j/current
ONEJ_ENV_FILE=/opt/100j/env/100j.env ONEJ_API_PORT=8020 docker compose --env-file /opt/100j/env/100j.env up -d --build
```

Rollback is currently redeploying the previous Git commit with `scripts/deploy-hz.sh`. The PostgreSQL volume is persistent and is not removed by normal restarts.
