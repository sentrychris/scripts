#!/usr/bin/env bash
set -euo pipefail

# Tail multiple files with a labelled prefix per line.
# Usage: log-tail-multi.sh <file1> [file2 ...]

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file1> [file2 ...]" >&2
    exit 1
fi

# Pick a color per file
colors=(31 32 33 34 35 36)
pids=()

cleanup() {
    for p in "${pids[@]}"; do
        kill "$p" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

i=0
for f in "$@"; do
    if [[ ! -r "$f" ]]; then
        echo "Warning: cannot read ${f}, skipping." >&2
        continue
    fi
    label="$(basename "$f")"
    color="${colors[$((i % ${#colors[@]}))]}"
    prefix=$'\033['"${color}"$'m['"${label}"$']\033[0m'

    tail -n 0 -F "$f" 2>/dev/null \
        | sed -u "s|^|${prefix} |" &
    pids+=($!)
    i=$((i + 1))
done

wait
