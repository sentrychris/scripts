#!/usr/bin/env bash
set -euo pipefail

# Dump MySQL/MariaDB databases, gzip, rotate by age.
# Reads credentials from /root/.my.cnf or MYSQL_PWD env.

BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"
KEEP_DAYS="${KEEP_DAYS:-14}"
DATABASES="${DATABASES:-}"               # space-separated, empty = all
EXCLUDE="${EXCLUDE:-information_schema performance_schema sys}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if ! command -v mysqldump >/dev/null 2>&1; then
    echo "Error: mysqldump not installed." >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

if [[ -z "$DATABASES" ]]; then
    DATABASES="$(mysql -Nse 'SHOW DATABASES;')"
fi

failed=()
for db in $DATABASES; do
    skip=0
    for ex in $EXCLUDE; do
        [[ "$db" == "$ex" ]] && skip=1
    done
    [[ $skip -eq 1 ]] && continue

    out="${BACKUP_DIR}/${db}-${TIMESTAMP}.sql.gz"
    echo "Dumping ${db} -> ${out}"
    if ! mysqldump --single-transaction --quick --routines --triggers \
            --events --set-gtid-purged=OFF "$db" 2>/dev/null | gzip -c > "$out"; then
        echo "  FAILED: ${db}" >&2
        rm -f "$out"
        failed+=("$db")
    fi
done

echo "Pruning backups older than ${KEEP_DAYS} days..."
find "$BACKUP_DIR" -maxdepth 1 -name '*.sql.gz' -mtime +"${KEEP_DAYS}" -print -delete

if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed databases: ${failed[*]}" >&2
    exit 1
fi
echo "Backup complete."
