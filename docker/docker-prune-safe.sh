#!/usr/bin/env bash
set -euo pipefail

# Reclaim docker disk safely. Volumes are NEVER pruned unless --volumes given.
# Usage: docker-prune-safe.sh [--apply] [--volumes] [--age 168h]

APPLY=0
VOLUMES=0
AGE="168h"   # 7 days

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)   APPLY=1; shift ;;
        --volumes) VOLUMES=1; shift ;;
        --age)     AGE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--apply] [--volumes] [--age 168h]"
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker not installed." >&2
    exit 1
fi

echo "==> Disk usage before"
docker system df

dry_args=()
[[ $APPLY -eq 0 ]] && dry_args+=(--filter "dangling=true")

echo ""
echo "==> Stopped containers (older than ${AGE})"
docker container ls -a --filter status=exited --filter status=dead \
    --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"

echo ""
echo "==> Dangling images"
docker images --filter dangling=true --format "table {{.ID}}\t{{.Repository}}\t{{.Size}}"

echo ""
echo "==> Unused networks"
docker network ls --filter type=custom

if [[ $APPLY -eq 0 ]]; then
    echo ""
    echo "(dry-run — re-run with --apply to actually prune)"
    exit 0
fi

echo ""
echo "Pruning containers older than ${AGE}..."
docker container prune -f --filter "until=${AGE}"

echo "Pruning dangling images..."
docker image prune -f

echo "Pruning unused networks..."
docker network prune -f --filter "until=${AGE}"

echo "Pruning build cache..."
docker builder prune -f --filter "until=${AGE}" 2>/dev/null || true

if [[ $VOLUMES -eq 1 ]]; then
    echo ""
    echo "WARNING: pruning unused volumes — data loss possible!"
    read -rp "Type DELETE to confirm: " c
    [[ "$c" == "DELETE" ]] && docker volume prune -f || echo "Skipped volumes."
fi

echo ""
echo "==> Disk usage after"
docker system df
