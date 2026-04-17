#!/usr/bin/env bash
set -euo pipefail

# Show top N largest files/directories under a path.
# Usage: disk-usage-top.sh [path] [count]   default: . 20

PATH_ARG="${1:-.}"
COUNT="${2:-20}"

if [[ ! -d "$PATH_ARG" ]]; then
    echo "Error: not a directory: $PATH_ARG" >&2
    exit 1
fi

echo "==> Top ${COUNT} entries (files + dirs) under ${PATH_ARG}"
du -ahx --max-depth=4 "$PATH_ARG" 2>/dev/null \
    | sort -rh \
    | head -n "$COUNT"

echo ""
echo "==> Top ${COUNT} immediate subdirectories"
du -hx --max-depth=1 "$PATH_ARG" 2>/dev/null \
    | sort -rh \
    | head -n "$COUNT"

echo ""
echo "==> Filesystem usage"
df -h "$PATH_ARG"
