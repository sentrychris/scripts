#!/usr/bin/env bash
set -euo pipefail

# Find duplicate files under a path by size + sha256.
# Usage: find-duplicates.sh [path] [min-size-bytes]   default: . 1048576 (1MB)

ROOT="${1:-.}"
MIN_SIZE="${2:-1048576}"

if [[ ! -d "$ROOT" ]]; then
    echo "Error: not a directory: $ROOT" >&2
    exit 1
fi

# 1) Group by size — only files sharing a size can possibly be duplicates.
# 2) Hash only those candidates.
echo "Scanning ${ROOT} (min size $(numfmt --to=iec "$MIN_SIZE" 2>/dev/null || echo "${MIN_SIZE}B"))..."

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# size <tab> path
find "$ROOT" -type f -size +"$((MIN_SIZE - 1))"c -printf '%s\t%p\n' 2>/dev/null > "$tmp"

# sizes that appear more than once
candidates="$(awk -F'\t' '{c[$1]++} END{for(s in c) if(c[s]>1) print s}' "$tmp")"

if [[ -z "$candidates" ]]; then
    echo "No same-size files found — no duplicates possible."
    exit 0
fi

# Hash candidates only
hashfile="$(mktemp)"
trap 'rm -f "$tmp" "$hashfile"' EXIT

while IFS= read -r size; do
    awk -F'\t' -v s="$size" '$1==s {print $2}' "$tmp" \
        | tr '\n' '\0' \
        | xargs -0 -r sha256sum 2>/dev/null \
        >> "$hashfile"
done <<< "$candidates"

# Group by hash, print groups with > 1
awk '
    { hash=$1; $1=""; sub(/^ /,""); paths[hash]=paths[hash] $0 "\n"; count[hash]++ }
    END { for (h in count) if (count[h]>1) {
        printf "==> %d copies (sha %s)\n%s\n", count[h], substr(h,1,12), paths[h]
    }}
' "$hashfile"
