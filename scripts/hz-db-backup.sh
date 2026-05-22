#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-deploy@118.178.122.194}"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_DIR:-/opt/100j/backups}"
DATABASE_NAME="${DATABASE_NAME:-100j}"
KEEP_BACKUPS="${KEEP_BACKUPS:-14}"

ssh "${REMOTE}" \
  "REMOTE_BACKUP_DIR='${REMOTE_BACKUP_DIR}' DATABASE_NAME='${DATABASE_NAME}' KEEP_BACKUPS='${KEEP_BACKUPS}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_file="${REMOTE_BACKUP_DIR}/${DATABASE_NAME}-${timestamp}.dump"
tmp_file="/tmp/${DATABASE_NAME}-${timestamp}.dump"

sudo install -d -o deploy -g deploy -m 750 "${REMOTE_BACKUP_DIR}"
sudo -u postgres pg_dump --format=custom --dbname="${DATABASE_NAME}" --file="${tmp_file}"
sudo install -o deploy -g deploy -m 640 "${tmp_file}" "${backup_file}"
sudo rm -f "${tmp_file}"

find "${REMOTE_BACKUP_DIR}" -maxdepth 1 -name "${DATABASE_NAME}-*.dump" -type f \
  | sort -r \
  | tail -n "+$((KEEP_BACKUPS + 1))" \
  | xargs -r rm -f

echo "${backup_file}"
REMOTE_SCRIPT
