#!/usr/bin/env bash
set -euo pipefail

# Restore a MySQL database from a gzipped dump produced by mysql-backup.sh.
# Usage: mysql-restore.sh <database> [dump-file]
# If dump-file is omitted, the latest matching backup is used.

BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if ! command -v mysql >/dev/null 2>&1; then
    echo "Error: mysql client not installed." >&2
    exit 1
fi

DB="${1:-}"
DUMP="${2:-}"

if [[ -z "$DB" ]]; then
    echo "Usage: $0 <database> [dump-file]" >&2
    exit 1
fi

if [[ -z "$DUMP" ]]; then
    DUMP="$(find "$BACKUP_DIR" -maxdepth 1 -name "${DB}-*.sql.gz" -printf '%T@ %p\n' \
            | sort -nr | head -n1 | cut -d' ' -f2-)"
    if [[ -z "$DUMP" ]]; then
        echo "Error: no backup found for ${DB} in ${BACKUP_DIR}." >&2
        exit 1
    fi
fi

if [[ ! -f "$DUMP" ]]; then
    echo "Error: dump file not found: $DUMP" >&2
    exit 1
fi

exists="$(mysql -Nse "SHOW DATABASES LIKE '${DB}';" || true)"

echo "About to restore:"
echo "  Database : ${DB} $([[ -n "$exists" ]] && echo '(EXISTS — will be overwritten)')"
echo "  Dump     : ${DUMP}  ($(du -h "$DUMP" | cut -f1))"
echo ""
read -rp "Continue? (y/N): " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

if [[ -n "$exists" ]]; then
    SAFETY="${BACKUP_DIR}/${DB}-pre-restore-$(date +%Y%m%d-%H%M%S).sql.gz"
    echo "Snapshotting current ${DB} to ${SAFETY}..."
    mysqldump --single-transaction --quick "$DB" | gzip -c > "$SAFETY"
fi

mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB}\`;"

echo "Restoring..."
gunzip -c "$DUMP" | mysql "$DB"

echo "Restore complete."
