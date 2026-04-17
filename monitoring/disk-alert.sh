#!/usr/bin/env bash
set -euo pipefail

# Exit non-zero if any local mountpoint exceeds the threshold. Cron-friendly.
# Usage: disk-alert.sh [threshold-percent] [--inodes-too]
# Default threshold: 85

THRESHOLD="${1:-85}"
CHECK_INODES=0
[[ "${2:-}" == "--inodes-too" ]] && CHECK_INODES=1

# Skip pseudo/network filesystems
EXCLUDE_TYPES='tmpfs|devtmpfs|squashfs|overlay|proc|sysfs|cgroup|fuse.snapfuse|nfs|nfs4|cifs'

over=0

# Disk space
while read -r src size used avail pct mount; do
    pct="${pct%%%}"
    if (( pct >= THRESHOLD )); then
        echo "DISK  ${pct}% used on ${mount}  (${used}/${size}, ${avail} free)"
        over=1
    fi
done < <(df -hPT | awk -v ex="$EXCLUDE_TYPES" '
    NR>1 && $2 !~ ex { print $1, $3, $4, $5, $6, $7 }')

if [[ $CHECK_INODES -eq 1 ]]; then
    while read -r src inodes iused ifree pct mount; do
        pct="${pct%%%}"
        [[ "$pct" =~ ^[0-9]+$ ]] || continue
        if (( pct >= THRESHOLD )); then
            echo "INODE ${pct}% used on ${mount}  (${iused}/${inodes} inodes)"
            over=1
        fi
    done < <(df -iPT | awk -v ex="$EXCLUDE_TYPES" '
        NR>1 && $2 !~ ex { print $1, $3, $4, $5, $6, $7 }')
fi

if [[ $over -eq 0 ]]; then
    echo "OK: all mountpoints below ${THRESHOLD}%"
fi
exit $over
