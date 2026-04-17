#!/usr/bin/env bash
set -euo pipefail

# Run `git pull --rebase` (or `git fetch`) across every git repo under a directory.
# Usage: repo-sync.sh [path]   default: current dir
#        FETCH_ONLY=1 repo-sync.sh   to fetch instead of pull

ROOT="${1:-.}"
FETCH_ONLY="${FETCH_ONLY:-0}"

if [[ ! -d "$ROOT" ]]; then
    echo "Error: not a directory: $ROOT" >&2
    exit 1
fi

failed=()
synced=0

while IFS= read -r -d '' gitdir; do
    repo="$(dirname "$gitdir")"
    name="${repo#${ROOT}/}"
    printf "==> %s\n" "$name"

    if ! branch="$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null)"; then
        echo "  (detached HEAD — skipping)"
        continue
    fi

    if ! git -C "$repo" diff --quiet || ! git -C "$repo" diff --cached --quiet; then
        echo "  (dirty working tree — fetching only)"
        if ! git -C "$repo" fetch --prune; then
            failed+=("$name")
        fi
        continue
    fi

    if [[ "$FETCH_ONLY" == "1" ]]; then
        if ! git -C "$repo" fetch --prune; then
            failed+=("$name")
        fi
    else
        if ! git -C "$repo" pull --rebase --prune; then
            failed+=("$name")
        fi
    fi
    synced=$((synced + 1))
done < <(find "$ROOT" -maxdepth 4 -type d -name .git -print0)

echo ""
echo "Processed ${synced} repo(s)."
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failures:"
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
