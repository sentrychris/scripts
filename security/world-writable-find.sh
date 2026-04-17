#!/usr/bin/env bash
set -euo pipefail

# Find world-writable files outside the expected locations.
# Usage: world-writable-find.sh [path]   default: /

ROOT="${1:-/}"

EXCLUDES=(
    /proc /sys /dev /run
    /tmp /var/tmp
    /var/lib/docker /var/lib/containerd
    /snap
)

prune_args=()
for e in "${EXCLUDES[@]}"; do
    prune_args+=(-path "$e" -prune -o)
done

echo "==> World-writable files (excluding ${EXCLUDES[*]})"
find "$ROOT" "${prune_args[@]}" \
    -type f -perm -0002 ! -perm -1000 -print 2>/dev/null

echo ""
echo "==> World-writable directories without sticky bit"
find "$ROOT" "${prune_args[@]}" \
    -type d -perm -0002 ! -perm -1000 -print 2>/dev/null

echo ""
echo "==> SUID binaries (review for surprises)"
find "$ROOT" "${prune_args[@]}" \
    -type f -perm -4000 -print 2>/dev/null
