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
- Runtime: Python venv + systemd on HZ
- API container: FastAPI + Alembic migrations
- DB: server PostgreSQL 16 database `100j`
- Local server port: `127.0.0.1:8020`
- Public ingress: Nginx HTTPS reverse proxy

The repository also includes `backend/Dockerfile` and `docker-compose.yml` as portable deployment
materials. HZ uses systemd because Docker Hub image pulls can be unreliable from the server network.

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
OWNER_CLOUD_ACCESS_CODE
EMAIL_OTP_ENABLED=false
APPLE_ALLOWED_AUDIENCES=top.linotsai.app.PersonalAffairs
PENDING_CONFIRMATION_EXPIRE_MINUTES
CORS_ORIGINS=https://100j.linotsai.top
```

Use random production secrets for `JWT_SECRET_KEY`, `POSTGRES_PASSWORD`, `LLM_KEY_ENCRYPTION_SECRET`, and `OWNER_CLOUD_ACCESS_CODE`.
The Apple apps use `OWNER_CLOUD_ACCESS_CODE` as the single-owner cloud access code, then store the returned JWT pair in Apple Keychain. P6 personal-account production keeps Email OTP disabled; `scripts/deploy-hz.sh` enforces `EMAIL_OTP_ENABLED=false`.

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

The script rsyncs backend deployment files to `/opt/100j/current`, creates `/opt/100j/env/100j.env` if missing, creates/updates the local PostgreSQL role and database, installs the backend plus the smoke-test extra into `/opt/100j/venv`, runs Alembic migrations through systemd, and checks local health.

On HZ the script defaults pip to the Alibaba Cloud PyPI mirror. Override with `PIP_INDEX_URL`, `PIP_DEFAULT_TIMEOUT`, or `PIP_RETRIES` if the mirror or network changes.

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
To verify the single-owner Apple login path without printing the secret, run the owner-login check from the server after sourcing `/opt/100j/env/100j.env`.

For the full production check from a local workstation:

```bash
scripts/prod-check.sh
```

The check verifies public HTTPS health, TLS certificate dates, remote `100j-api.service`, Nginx,
certbot timer, local server health, latest backup presence, recent API/Nginx errors, and the
production smoke test.

## Operations

```bash
ssh deploy@118.178.122.194
cd /opt/100j/current
systemctl status 100j-api --no-pager
journalctl -u 100j-api -n 100 --no-pager
curl -fsS http://127.0.0.1:8020/health
```

Restart:

```bash
sudo systemctl restart 100j-api
```

## Backup And Restore Rehearsal

Create a production PostgreSQL backup on HZ:

```bash
scripts/hz-db-backup.sh
```

Backups are custom-format PostgreSQL dumps stored on the server under `/opt/100j/backups`.
The script keeps the latest 14 dumps by default; override with `KEEP_BACKUPS`.

Rehearse restoring the latest backup into a temporary database:

```bash
scripts/hz-db-restore-rehearsal.sh
```

The rehearsal restores into a fresh database named like `100j_restore_rehearsal_YYYYMMDD_HHMMSS`,
checks public tables, users, and Alembic version, then drops the temporary database. Set
`KEEP_REHEARSAL_DB=1` when you need to inspect the restored database manually.

Rollback is currently redeploying the previous Git commit with `scripts/deploy-hz.sh`. The PostgreSQL database is persistent and is not removed by normal restarts.

## Release Candidate Verification

Run the local release gate before distributing a new app build:

```bash
scripts/verify-release.sh
```

Set `RUN_PROD_CHECK=1` to include the HZ production check in the same run:

```bash
RUN_PROD_CHECK=1 scripts/verify-release.sh
```

## v1.2.4 Upgrade Notes

Mandatory steps when upgrading an existing HZ deployment from v1.2.3 to v1.2.4:

1. Run the LLM key re-derivation migration before restarting the API service:

   ```bash
   ssh deploy@118.178.122.194 \
     "cd /opt/100j/current/backend && /opt/100j/venv/bin/python -m scripts.migrate_llm_keys_v124"
   ```

   P0-2 changed the LLM key encryption derivation. Existing encrypted keys must be re-derived once; the migrator is idempotent.

2. Confirm `/opt/100j/env/100j.env` contains the v1.2.4 settings before the first restart:

   - `REGISTER_INVITE_TOKEN=` (empty in production unless onboarding a new owner; gates `/auth/register`).
   - `SMTP_HOST=...` when `EMAIL_OTP_ENABLED=true`; the runtime validator now refuses to boot in production if OTP is on without SMTP configured.
   - `APPLE_SIGN_IN_ENABLED=false` (default; flip to `true` only after entitlements + AppleID + privacy policy land in v1.3.0).

3. `alembic upgrade head` will execute `0006_refresh_token_jti`. This migration adds the refresh-token JTI blacklist table required for rotation. `scripts/deploy-hz.sh` runs Alembic via systemd as part of the normal deploy.

4. The systemd unit `100j-api.service` `ExecStart` now appends `--proxy-headers --forwarded-allow-ips=127.0.0.1` so that rate-limit key derivation sees the real client IP through Nginx. `scripts/deploy-hz.sh` writes the new unit file, but existing machines must be reloaded explicitly:

   ```bash
   ssh deploy@118.178.122.194 "sudo systemctl daemon-reload && sudo systemctl restart 100j-api"
   ```

After deploy, run `scripts/prod-check.sh` to verify the new auth surface (`/auth/register` 404 without invite, `/auth/device-logout` 401 without auth, real client IP visible to the rate limiter).
