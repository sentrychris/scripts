#!/usr/bin/env bash
set -euo pipefail

# Run a 60-second mtr report against a host and save it.
# Usage: mtr-report.sh <host> [seconds]   default 60

HOST="${1:-}"
SECONDS_TO_RUN="${2:-60}"
OUT_DIR="${OUT_DIR:-./mtr-reports}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <host> [seconds]" >&2
    exit 1
fi

if ! command -v mtr >/dev/null 2>&1; then
    echo "Error: mtr not installed." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
ts="$(date +%Y%m%d-%H%M%S)"
out="${OUT_DIR}/mtr-${HOST}-${ts}.txt"

# 10 packets per second -> count = seconds * 10
count=$(( SECONDS_TO_RUN * 10 ))

echo "Running mtr to ${HOST} for ${SECONDS_TO_RUN}s..."
{
    echo "# mtr report"
    echo "# host:    ${HOST}"
    echo "# started: $(date -Is)"
    echo "# from:    $(hostname)"
    echo ""
    mtr --report --report-wide --show-ips --tcp \
        --report-cycles "$count" \
        --interval 0.1 \
        "$HOST"
} | tee "$out"

echo ""
echo "Saved: ${out}"
