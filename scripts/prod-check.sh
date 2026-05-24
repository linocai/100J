#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-100j.linotsai.top}"
HZ_IP="${HZ_IP:-118.178.122.194}"
REMOTE="${REMOTE:-deploy@118.178.122.194}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/100j/current}"
REMOTE_API_PORT="${REMOTE_API_PORT:-8020}"
RUN_REMOTE="${RUN_REMOTE:-1}"
RUN_SMOKE="${RUN_SMOKE:-1}"
JOURNAL_SINCE="${JOURNAL_SINCE:-30 minutes ago}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="https://${DOMAIN}"
RESOLVE_ARG=()

if [[ -n "$HZ_IP" ]]; then
  RESOLVE_ARG=(--resolve "${DOMAIN}:443:${HZ_IP}")
fi

section() {
  printf "\n== %s ==\n" "$1"
}

section "Public health"
curl -fsS "${RESOLVE_ARG[@]}" "${BASE_URL}/health"
printf "\n"
curl -fsS "${RESOLVE_ARG[@]}" "${BASE_URL}/api/v1/health"
printf "\n"

section "Auth surface (v1.2.4)"
register_code=$(curl -s -o /dev/null -w "%{http_code}" "${RESOLVE_ARG[@]}" \
  -X POST "${BASE_URL}/api/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d '{}')
if [[ "$register_code" != "404" ]]; then
  echo "Expected /auth/register to return 404 in production, got ${register_code}" >&2
  exit 1
fi
echo "/auth/register -> ${register_code} (expected 404)"

device_logout_code=$(curl -s -o /dev/null -w "%{http_code}" "${RESOLVE_ARG[@]}" \
  -X POST "${BASE_URL}/api/v1/auth/device-logout" \
  -H 'Content-Type: application/json' \
  -d '{"device_id":"x"}')
if [[ "$device_logout_code" != "401" ]]; then
  echo "Expected /auth/device-logout to return 401 without auth, got ${device_logout_code}" >&2
  exit 1
fi
echo "/auth/device-logout -> ${device_logout_code} (expected 401)"

section "Proxy header rate-limit attribution"
# Hit /health through the public ingress with a synthetic X-Forwarded-For so
# the slowapi key_func observes 8.8.8.8 instead of the Nginx loopback. The
# request must succeed (2xx); a 502/504 here means proxy-headers regressed and
# uvicorn rejected the forwarded chain.
forwarded_code=$(curl -s -o /dev/null -w "%{http_code}" "${RESOLVE_ARG[@]}" \
  -H 'X-Forwarded-For: 8.8.8.8' \
  "${BASE_URL}/health")
if [[ "$forwarded_code" != "200" ]]; then
  echo "Expected /health with X-Forwarded-For to return 200, got ${forwarded_code}" >&2
  exit 1
fi
echo "/health (X-Forwarded-For: 8.8.8.8) -> ${forwarded_code} (expected 200)"

section "TLS certificate"
tls_connect_host="${HZ_IP:-$DOMAIN}"
echo | openssl s_client -servername "$DOMAIN" -connect "${tls_connect_host}:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates

if [[ "$RUN_REMOTE" == "1" ]]; then
  section "Remote services"
  ssh "$REMOTE" \
    "set -eu
     systemctl is-active 100j-api.service
     systemctl is-active nginx
     systemctl is-active certbot.timer
     curl -fsS http://127.0.0.1:${REMOTE_API_PORT}/health
     printf '\n'
     latest_backup=\$(ls -1t /opt/100j/backups/*.dump 2>/dev/null | head -1 || true)
     if [ -n \"\$latest_backup\" ]; then
       ls -lh \"\$latest_backup\"
     else
       echo 'No backup dump found under /opt/100j/backups' >&2
       exit 1
     fi"

  section "Recent API errors"
  ssh "$REMOTE" \
    "sudo journalctl -u 100j-api.service --since '${JOURNAL_SINCE}' -p err --no-pager || true"

  section "Recent Nginx errors"
  ssh "$REMOTE" \
    "if [ -f /var/log/nginx/error.log ]; then sudo tail -n 80 /var/log/nginx/error.log; fi"
fi

if [[ "$RUN_SMOKE" == "1" ]]; then
  section "Production smoke"
  if [[ "$RUN_REMOTE" == "1" ]]; then
    ssh "$REMOTE" \
      "cd '${REMOTE_APP_DIR}/backend' && /opt/100j/venv/bin/python scripts/phase4_smoke.py --base-url '${BASE_URL}' --env prod"
  else
    (cd "$ROOT_DIR/backend" && .venv/bin/python scripts/phase4_smoke.py --base-url "$BASE_URL" --env prod)
  fi
fi

section "Result"
echo "production check passed for ${BASE_URL}"
