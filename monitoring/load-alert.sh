#!/usr/bin/env bash
set -euo pipefail

# Exit non-zero if 15-min load average exceeds N * CPU count. Cron-friendly.
# Usage: load-alert.sh [multiplier]   default: 1.5

MULT="${1:-1.5}"

cpus="$(nproc)"
read -r l1 l5 l15 _ < /proc/loadavg

# threshold = cpus * mult, computed in awk to avoid bc dependency
threshold="$(awk -v c="$cpus" -v m="$MULT" 'BEGIN { printf "%.2f", c*m }')"

over="$(awk -v l="$l15" -v t="$threshold" 'BEGIN { print (l > t) ? 1 : 0 }')"

if [[ "$over" == "1" ]]; then
    echo "HIGH LOAD  load15=${l15}  threshold=${threshold}  (cpus=${cpus} x ${MULT})"
    echo ""
    echo "==> Top processes by CPU"
    ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -n 11
    exit 1
fi

echo "OK: load15=${l15}  load5=${l5}  load1=${l1}  (cpus=${cpus}, threshold=${threshold})"
exit 0
