#!/usr/bin/env bash
set -euo pipefail

# List listening ports and which process owns each.
# Usage: port-check.sh [port]   if no port given, lists all.

PORT="${1:-}"

if ! command -v ss >/dev/null 2>&1; then
    echo "Error: ss (iproute2) not installed." >&2
    exit 1
fi

need_root=0
if [[ $EUID -ne 0 ]]; then
    echo "Note: run as root to see process names for all sockets." >&2
    need_root=1
fi

if [[ -n "$PORT" ]]; then
    echo "==> Listeners on port ${PORT}"
    ss -tulnp "sport = :${PORT}" 2>/dev/null || ss -tulnp | awk -v p=":${PORT}" '$5 ~ p'
    if command -v lsof >/dev/null 2>&1 && [[ $need_root -eq 0 ]]; then
        echo ""
        echo "==> lsof for port ${PORT}"
        lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true
        lsof -nP -iUDP:"${PORT}" 2>/dev/null || true
    fi
else
    echo "==> All listening sockets"
    ss -tulnp
fi
