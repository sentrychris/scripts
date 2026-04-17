#!/usr/bin/env bash
set -euo pipefail

# Find files larger than N MB not accessed in M days. Cleanup candidates.
# Usage: largest-old-files.sh [path] [min-mb] [unaccessed-days] [count]
# Defaults: . 100 90 30

ROOT="${1:-.}"
MIN_MB="${2:-100}"
DAYS="${3:-90}"
COUNT="${4:-30}"

if [[ ! -d "$ROOT" ]]; then
    echo "Error: not a directory: $ROOT" >&2
    exit 1
fi

echo "Scanning ${ROOT} for files >= ${MIN_MB}MB not accessed in ${DAYS} days..."

find "$ROOT" -xdev -type f \
    -size +"${MIN_MB}M" \
    -atime +"${DAYS}" \
    -printf '%s\t%TY-%Tm-%Td\t%AY-%Am-%Ad\t%p\n' 2>/dev/null \
    | sort -rn \
    | head -n "$COUNT" \
    | awk -F'\t' '
        BEGIN { printf "%-10s %-12s %-12s %s\n", "SIZE", "MODIFIED", "ACCESSED", "PATH"
                printf "%-10s %-12s %-12s %s\n", "----", "--------", "--------", "----" }
        {
            s=$1
            unit="B"
            if (s>=1073741824) { s=s/1073741824; unit="G" }
            else if (s>=1048576) { s=s/1048576; unit="M" }
            else if (s>=1024)    { s=s/1024;    unit="K" }
            printf "%6.1f%s   %-12s %-12s %s\n", s, unit, $2, $3, $4
        }'
