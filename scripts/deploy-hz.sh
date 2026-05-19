#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-deploy@118.178.122.194}"
DOMAIN="${DOMAIN:-100j.linotsai.top}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/100j/current}"
REMOTE_ENV_DIR="${REMOTE_ENV_DIR:-/opt/100j/env}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-/opt/100j/env/100j.env}"
REMOTE_VENV_DIR="${REMOTE_VENV_DIR:-/opt/100j/venv}"
REMOTE_API_PORT="${REMOTE_API_PORT:-8020}"
PIP_INDEX_URL="${PIP_INDEX_URL:-https://mirrors.aliyun.com/pypi/simple/}"
PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-60}"
PIP_RETRIES="${PIP_RETRIES:-5}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Deploying 100J backend to ${REMOTE}:${REMOTE_APP_DIR}"

ssh "${REMOTE}" "sudo install -d -o deploy -g deploy '${REMOTE_APP_DIR}' '${REMOTE_ENV_DIR}' '${REMOTE_VENV_DIR}'"

rsync -az --delete \
  --exclude '.git' \
  --exclude '.DS_Store' \
  --exclude 'backend/.venv' \
  --exclude 'backend/.pytest_cache' \
  --exclude 'frontend/apple/.build' \
  --exclude 'frontend/apple/.swiftpm' \
  "${ROOT_DIR}/backend" \
  "${ROOT_DIR}/docker-compose.yml" \
  "${ROOT_DIR}/deployment.md" \
  "${REMOTE}:${REMOTE_APP_DIR}/"

ssh "${REMOTE}" \
  "REMOTE_ENV_FILE='${REMOTE_ENV_FILE}' REMOTE_APP_DIR='${REMOTE_APP_DIR}' REMOTE_VENV_DIR='${REMOTE_VENV_DIR}' REMOTE_API_PORT='${REMOTE_API_PORT}' DOMAIN='${DOMAIN}' PIP_INDEX_URL='${PIP_INDEX_URL}' PIP_DEFAULT_TIMEOUT='${PIP_DEFAULT_TIMEOUT}' PIP_RETRIES='${PIP_RETRIES}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

if [ ! -f "${REMOTE_ENV_FILE}" ]; then
  umask 077
  db_password="$(openssl rand -hex 24)"
  jwt_secret="$(openssl rand -hex 48)"
  llm_secret="$(openssl rand -hex 48)"
  owner_access_code="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
  cat > "${REMOTE_ENV_FILE}" <<ENV_FILE
APP_ENV=production
AUTH_MODE=jwt
DATABASE_URL=postgresql+psycopg://100j:${db_password}@127.0.0.1:5432/100j
POSTGRES_DB=100j
POSTGRES_USER=100j
POSTGRES_PASSWORD=${db_password}
JWT_SECRET_KEY=${jwt_secret}
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30
LLM_KEY_ENCRYPTION_SECRET=${llm_secret}
OWNER_CLOUD_ACCESS_CODE=${owner_access_code}
PENDING_CONFIRMATION_EXPIRE_MINUTES=15
CORS_ORIGINS=https://${DOMAIN}
ENV_FILE
fi
chmod 600 "${REMOTE_ENV_FILE}"

if ! grep -q '^OWNER_CLOUD_ACCESS_CODE=' "${REMOTE_ENV_FILE}"; then
  owner_access_code="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
  printf '\nOWNER_CLOUD_ACCESS_CODE=%s\n' "${owner_access_code}" >> "${REMOTE_ENV_FILE}"
fi

db_password="$(grep '^POSTGRES_PASSWORD=' "${REMOTE_ENV_FILE}" | cut -d= -f2-)"
if grep -q '@db:5432' "${REMOTE_ENV_FILE}"; then
  cp "${REMOTE_ENV_FILE}" "${REMOTE_ENV_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
  python3 - "${REMOTE_ENV_FILE}" "${db_password}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
password = sys.argv[2]
lines = path.read_text().splitlines()
next_lines = []
for line in lines:
    if line.startswith("DATABASE_URL="):
        next_lines.append(f"DATABASE_URL=postgresql+psycopg://100j:{password}@127.0.0.1:5432/100j")
    else:
        next_lines.append(line)
path.write_text("\n".join(next_lines) + "\n")
PY
fi

if [ "$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='100j'")" != "1" ]; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE \"100j\" LOGIN PASSWORD '${db_password}';"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE \"100j\" WITH LOGIN PASSWORD '${db_password}';"
fi

if [ "$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='100j'")" != "1" ]; then
  sudo -u postgres createdb -O "100j" "100j"
fi

python3 -m venv "${REMOTE_VENV_DIR}"
"${REMOTE_VENV_DIR}/bin/python" -m pip install --upgrade pip \
  --index-url "${PIP_INDEX_URL}" \
  --timeout "${PIP_DEFAULT_TIMEOUT}" \
  --retries "${PIP_RETRIES}"
"${REMOTE_VENV_DIR}/bin/python" -m pip install -e "${REMOTE_APP_DIR}/backend[smoke]" \
  --index-url "${PIP_INDEX_URL}" \
  --timeout "${PIP_DEFAULT_TIMEOUT}" \
  --retries "${PIP_RETRIES}"

sudo tee /etc/systemd/system/100j-api.service >/dev/null <<SERVICE
[Unit]
Description=100J Personal Affairs API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=${REMOTE_APP_DIR}/backend
EnvironmentFile=${REMOTE_ENV_FILE}
ExecStartPre=${REMOTE_VENV_DIR}/bin/alembic upgrade head
ExecStart=${REMOTE_VENV_DIR}/bin/uvicorn app.main:app --host 127.0.0.1 --port ${REMOTE_API_PORT}
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/100j

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now 100j-api.service
sudo systemctl restart 100j-api.service

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${REMOTE_API_PORT}/health" >/dev/null; then
    curl -fsS "http://127.0.0.1:${REMOTE_API_PORT}/health"
    exit 0
  fi
  sleep 1
done

sudo systemctl status 100j-api.service --no-pager
exit 1
REMOTE_SCRIPT

echo "100J API is running locally on the server at 127.0.0.1:${REMOTE_API_PORT}"
