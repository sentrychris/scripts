#!/usr/bin/env bash
set -euo pipefail

# Delete local branches already merged into main/master.
# Usage: git-prune-merged.sh [--apply]   (default: dry-run)

APPLY=0
BASE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        --base)  BASE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--apply] [--base <branch>]"
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repo." >&2
    exit 1
fi

if [[ -z "$BASE" ]]; then
    for cand in main master trunk; do
        if git show-ref --verify --quiet "refs/heads/${cand}"; then
            BASE="$cand"
            break
        fi
    done
fi

if [[ -z "$BASE" ]]; then
    echo "Error: could not detect base branch (try --base <name>)." >&2
    exit 1
fi

current="$(git symbolic-ref --short HEAD 2>/dev/null || echo '')"

echo "Updating ${BASE}..."
git fetch --prune --quiet

merged="$(git branch --merged "$BASE" \
    | sed 's/^[* ] //' \
    | grep -vE "^(${BASE}|${current})$" || true)"

if [[ -z "$merged" ]]; then
    echo "Nothing to prune."
    exit 0
fi

echo ""
echo "Branches merged into ${BASE}:"
echo "$merged" | sed 's/^/  /'
echo ""

if [[ $APPLY -eq 1 ]]; then
    echo "$merged" | xargs -r -n1 git branch -d
    echo "Done."
else
    echo "(dry-run — re-run with --apply to delete)"
fi
