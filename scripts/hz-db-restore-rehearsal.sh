#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-deploy@118.178.122.194}"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_DIR:-/opt/100j/backups}"
DATABASE_NAME="${DATABASE_NAME:-100j}"
BACKUP_FILE="${BACKUP_FILE:-}"
KEEP_REHEARSAL_DB="${KEEP_REHEARSAL_DB:-0}"

ssh "${REMOTE}" \
  "REMOTE_BACKUP_DIR='${REMOTE_BACKUP_DIR}' DATABASE_NAME='${DATABASE_NAME}' BACKUP_FILE='${BACKUP_FILE}' KEEP_REHEARSAL_DB='${KEEP_REHEARSAL_DB}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

if [ -z "${BACKUP_FILE}" ]; then
  BACKUP_FILE="$(find "${REMOTE_BACKUP_DIR}" -maxdepth 1 -name "${DATABASE_NAME}-*.dump" -type f | sort | tail -1)"
fi

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "Backup file not found. Run scripts/hz-db-backup.sh first." >&2
  exit 1
fi

rehearsal_db="${DATABASE_NAME}_restore_rehearsal_$(date +%Y%m%d_%H%M%S)"
tmp_file="/tmp/$(basename "${BACKUP_FILE}").restore"
cleanup() {
  if [ "${KEEP_REHEARSAL_DB}" != "1" ]; then
    sudo -u postgres dropdb --if-exists "${rehearsal_db}" >/dev/null
  fi
  sudo rm -f "${tmp_file}"
}
trap cleanup EXIT

sudo install -o postgres -g postgres -m 600 "${BACKUP_FILE}" "${tmp_file}"
sudo -u postgres createdb -O "${DATABASE_NAME}" "${rehearsal_db}"
sudo -u postgres pg_restore --dbname="${rehearsal_db}" "${tmp_file}"

table_count="$(sudo -u postgres psql --dbname="${rehearsal_db}" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")"
user_count="$(sudo -u postgres psql --dbname="${rehearsal_db}" -tAc "SELECT count(*) FROM users;")"
alembic_version="$(sudo -u postgres psql --dbname="${rehearsal_db}" -tAc "SELECT version_num FROM alembic_version LIMIT 1;")"

if [ "${table_count}" -lt 1 ]; then
  echo "Restore rehearsal failed: no public tables restored." >&2
  exit 1
fi

echo "restore rehearsal ok"
echo "backup_file=${BACKUP_FILE}"
echo "rehearsal_db=${rehearsal_db}"
echo "public_tables=${table_count}"
echo "users=${user_count}"
echo "alembic_version=${alembic_version}"
REMOTE_SCRIPT
