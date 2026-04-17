#!/usr/bin/env bash
set -euo pipefail

# Wrapper around restic with sensible excludes and a prune policy.
# Expects RESTIC_REPOSITORY and RESTIC_PASSWORD_FILE in env or /etc/restic.env.

ENV_FILE="${ENV_FILE:-/etc/restic.env}"
PATHS=("${PATHS[@]:-/etc /home /var/www /root}")
EXCLUDES=(
    "/home/*/.cache"
    "/home/*/.local/share/Trash"
    "/var/cache"
    "/var/tmp"
    "*.tmp"
    "node_modules"
    ".venv"
    "__pycache__"
)

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if ! command -v restic >/dev/null 2>&1; then
    echo "Error: restic not installed." >&2
    exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    echo "Error: RESTIC_REPOSITORY not set (export it or put it in ${ENV_FILE})." >&2
    exit 1
fi

exclude_args=()
for e in "${EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$e")
done

echo "Backing up: ${PATHS[*]}"
restic backup "${exclude_args[@]}" "${PATHS[@]}"

echo "Pruning old snapshots..."
restic forget \
    --keep-daily   "$KEEP_DAILY" \
    --keep-weekly  "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --prune

echo "Verifying repo integrity..."
restic check --read-data-subset=5%
echo "Done."
