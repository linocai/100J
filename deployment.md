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

## v1.2.4 Deployment Runbook

End-to-end procedure for upgrading the HZ deployment from v1.2.3 to v1.2.4. Treat the whole runbook as a single maintenance window (≈15 minutes); LLM agent calls should be paused until step 7 completes.

### 0. Prerequisites (run from your laptop, not the server)

```bash
# Confirm local main is at v1.2.4 and CI was green
cd /Users/linotsai/Lino/100%J
git fetch --tags
git log --oneline -1 v1.2.4           # expect: 8987b8d
scripts/verify-release.sh              # full local gate, must exit 0
```

If anything in step 0 fails, stop — do not touch the server.

### 1. Snapshot the production database

Always take a fresh backup before a schema-changing release. v1.2.4 adds `0006_refresh_token_jti` and rewrites every row in `llm_provider_keys`.

```bash
ssh deploy@118.178.122.194 "/opt/100j/current/scripts/hz-db-backup.sh"
# Expect: a new file appears under /opt/100j/backups/100j_YYYYMMDD_HHMMSS.dump
ssh deploy@118.178.122.194 "ls -lt /opt/100j/backups/ | head -3"
```

### 2. Edit the production env file (still on the server)

```bash
ssh deploy@118.178.122.194 "sudo vim /opt/100j/env/100j.env"
```

Add or confirm these keys:

```dotenv
# v1.2.4 — registration is closed by default. Leave empty unless onboarding a new owner.
REGISTER_INVITE_TOKEN=

# v1.2.4 — Apple Sign-In remains feature-gated off until v1.3.0.
APPLE_SIGN_IN_ENABLED=false

# v1.2.4 — required only if EMAIL_OTP_ENABLED=true. HZ keeps OTP disabled, so leave SMTP_* empty.
# SMTP_HOST=
# SMTP_PORT=465
# SMTP_USER=
# SMTP_PASSWORD=
# SMTP_FROM=

# v1.2.4 #15 — LLM key encryption salt. Must be >=16 bytes in prod; generate fresh:
#   openssl rand -hex 16
LLM_KEY_ENCRYPTION_SALT=<paste-16+ bytes of hex>
```

Keep the file mode at `600`:

```bash
ssh deploy@118.178.122.194 "sudo chmod 600 /opt/100j/env/100j.env && sudo chown deploy:deploy /opt/100j/env/100j.env"
```

If `JWT_SECRET_KEY` or `LLM_KEY_ENCRYPTION_SECRET` was ever set to a short or `change-me` value, rotate it now — the v1.2.4 runtime validator (`validate_runtime_settings`) refuses to boot otherwise. Rotating `LLM_KEY_ENCRYPTION_SECRET` means existing LLM keys must be re-entered by the user; coordinate that out-of-band.

### 3. Deploy the code (from your laptop)

```bash
cd /Users/linotsai/Lino/100%J
scripts/deploy-hz.sh
```

What this does, in order:

1. rsyncs `backend/` to `/opt/100j/current`
2. installs the new venv (`/opt/100j/venv`)
3. runs `alembic upgrade head` — applies `0006_refresh_token_jti`
4. rewrites the systemd unit so `ExecStart` includes `--proxy-headers --forwarded-allow-ips=127.0.0.1`
5. `daemon-reload` + `restart 100j-api`
6. local health check on the server

A clean run ends with `deploy-hz: OK`. Any non-zero exit stops here — investigate before continuing.

### 4. Migrate LLM provider keys (must run **after** step 3)

The script needs v1.2.4 code on disk to import the new `llm_key_encryption_salt` setting. Run it immediately after the deploy and **before** the owner uses the agent again.

```bash
ssh deploy@118.178.122.194 \
  "set -a && . /opt/100j/env/100j.env && set +a && cd /opt/100j/current/backend && /opt/100j/venv/bin/python -m scripts.migrate_llm_keys_v124"
```

The `set -a && . /opt/100j/env/100j.env && set +a` prefix is required because one-shot SSH commands do not load systemd's `EnvironmentFile`. Without it the script falls back to the default SQLite URL and fails with `no such table: llm_provider_keys`.

Expected output:

```
migrate_llm_keys_v124 done: total=N migrated=N already_new=0 failed=0
```

`already_new=N` on a re-run is fine — the script is idempotent. If `failed > 0`, see Recovery below.

### 5. Reload nginx if its config changed

`deploy-hz.sh` does not touch `/etc/nginx/sites-available/100j`. If you have ever added or removed an `X-Forwarded-For` directive, run:

```bash
ssh deploy@118.178.122.194 "sudo nginx -t && sudo systemctl reload nginx"
```

### 6. Verify the deployment

From your laptop (smoke + auth-surface checks):

```bash
cd /Users/linotsai/Lino/100%J
RUN_PROD_CHECK=1 scripts/verify-release.sh
```

This runs the full local gate plus `scripts/prod-check.sh`, which now asserts:

- `POST /auth/register` returns `404` (registration disabled in prod)
- `POST /auth/device-logout` returns `401` without auth headers
- `GET /health` honors `X-Forwarded-For` through nginx (no 5xx)
- `/api/v1/health` and the smoke suite both succeed against the public URL

On the server, spot-check:

```bash
ssh deploy@118.178.122.194 "systemctl status 100j-api --no-pager | head -20"
ssh deploy@118.178.122.194 "journalctl -u 100j-api -n 100 --no-pager | grep -iE 'error|traceback' || echo 'no errors'"
ssh deploy@118.178.122.194 "psql -d 100j -c 'SELECT count(*) FROM refresh_token_jti'"
```

`refresh_token_jti` should be `0` immediately after deploy and grow as users sign in / refresh.

### 7. Owner smoke checklist

Run through these manually on the real Apple clients (this is the v1.2.4 critical-fix acceptance from `PROJECT_PLAN_v1.2.4.md` §7.3):

- macOS: sign in → leave the app open 30+ minutes → keep using it; no "session expired" toast (#1 device session refresh)
- macOS: edit a Calendar item, toggle timed ↔ all-day, save; the change persists, no silent 422 (#4)
- macOS: trigger a risky Agent operation → dismiss the confirmation sheet → use the new banner on AgentScreen to reopen it → confirm (#32)
- iOS: turn airplane mode on, create 3 tasks, turn airplane mode off; all three sync (no `dropPermanent` in DiagnosticLogger) (#26 #31)
- iOS: sign out user A, sign in as a different account; user A's offline writes do not surface on the new account (#9)

### Recovery

| Symptom | Action |
| --- | --- |
| `alembic upgrade head` fails in step 3 | systemd will not start. Restore from the backup taken in step 1 (`pg_restore`), then `git checkout v1.2.3` on the server and redeploy. |
| Step 4 reports `failed > 0` | A row's ciphertext is corrupt or used a different secret. Identify the row from stderr (`id`, `user_id`), have the owner re-enter the LLM key via the Agent settings; the new write uses v1.2.4 derivation directly. |
| `/auth/login` returns 500 for everyone | Likely `validate_runtime_settings` rejected the env. Tail `journalctl -u 100j-api -n 50` and read the boot error; usually `JWT_SECRET_KEY` or `LLM_KEY_ENCRYPTION_SECRET` is too short or contains `change-me`. Fix the env, then `sudo systemctl restart 100j-api`. |
| Rate-limit attribution still looks like 127.0.0.1 | The systemd unit was not refreshed. `ssh deploy@... "sudo systemctl daemon-reload && sudo systemctl restart 100j-api"`. |
| Full rollback | `ssh deploy@... "cd /opt/100j/current && git checkout v1.2.3 && /opt/100j/venv/bin/alembic downgrade -1 && sudo systemctl restart 100j-api"`. LLM keys written by v1.2.4 will not decrypt under v1.2.3; restore the DB backup if the owner used LLM features after step 4. |
