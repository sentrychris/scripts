#!/usr/bin/env bash
set -euo pipefail

# Wide live table of container resource usage.
# Usage: docker-stats-watch.sh [interval-seconds]   default: 2

INTERVAL="${1:-2}"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker not installed." >&2
    exit 1
fi

fmt='table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'

if command -v watch >/dev/null 2>&1; then
    exec watch -n "$INTERVAL" -t "docker stats --no-stream --format '${fmt}'"
fi

# Fallback if `watch` is missing
trap 'echo; exit 0' INT
while true; do
    clear
    date
    docker stats --no-stream --format "$fmt"
    sleep "$INTERVAL"
done
