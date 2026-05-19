#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-deploy@118.178.122.194}"
DOMAIN="${DOMAIN:-100j.linotsai.top}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/100j/current}"
REMOTE_ENV_DIR="${REMOTE_ENV_DIR:-/opt/100j/env}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-/opt/100j/env/100j.env}"
REMOTE_API_PORT="${REMOTE_API_PORT:-8020}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Deploying 100J backend to ${REMOTE}:${REMOTE_APP_DIR}"

ssh "${REMOTE}" "mkdir -p '${REMOTE_APP_DIR}' '${REMOTE_ENV_DIR}'"

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

ssh "${REMOTE}" "REMOTE_ENV_FILE='${REMOTE_ENV_FILE}' DOMAIN='${DOMAIN}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail
if [ ! -f "${REMOTE_ENV_FILE}" ]; then
  umask 077
  db_password="$(openssl rand -hex 24)"
  jwt_secret="$(openssl rand -hex 48)"
  llm_secret="$(openssl rand -hex 48)"
  cat > "${REMOTE_ENV_FILE}" <<ENV_FILE
APP_ENV=production
AUTH_MODE=jwt
DATABASE_URL=postgresql+psycopg://100j:${db_password}@db:5432/100j
POSTGRES_DB=100j
POSTGRES_USER=100j
POSTGRES_PASSWORD=${db_password}
JWT_SECRET_KEY=${jwt_secret}
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30
LLM_KEY_ENCRYPTION_SECRET=${llm_secret}
PENDING_CONFIRMATION_EXPIRE_MINUTES=15
CORS_ORIGINS=https://${DOMAIN}
ENV_FILE
fi
chmod 600 "${REMOTE_ENV_FILE}"
REMOTE_SCRIPT

ssh "${REMOTE}" "cd '${REMOTE_APP_DIR}' && ONEJ_ENV_FILE='${REMOTE_ENV_FILE}' ONEJ_API_PORT='${REMOTE_API_PORT}' docker compose --env-file '${REMOTE_ENV_FILE}' up -d --build"
ssh "${REMOTE}" "curl -fsS 'http://127.0.0.1:${REMOTE_API_PORT}/health'"

echo "100J API is running locally on the server at 127.0.0.1:${REMOTE_API_PORT}"
