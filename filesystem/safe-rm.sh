#!/usr/bin/env bash
set -euo pipefail

# Move files/dirs to a dated trash directory instead of deleting.
# Usage: safe-rm.sh <path> [path ...]
#        safe-rm.sh --empty           empty the trash
#        safe-rm.sh --list            list trash contents

TRASH="${TRASH:-$HOME/.local/share/safe-rm}"
mkdir -p "$TRASH"

case "${1:-}" in
    "")
        echo "Usage: $0 <path> [path ...]   |  --list  |  --empty"
        exit 1 ;;
    --list)
        if [[ ! -d "$TRASH" || -z "$(ls -A "$TRASH" 2>/dev/null)" ]]; then
            echo "Trash is empty: ${TRASH}"
            exit 0
        fi
        du -sh "$TRASH"/* 2>/dev/null | sort -rh
        exit 0 ;;
    --empty)
        if [[ ! -d "$TRASH" ]]; then
            echo "Nothing to empty."
            exit 0
        fi
        size="$(du -sh "$TRASH" | cut -f1)"
        echo "About to permanently delete ${size} from ${TRASH}"
        read -rp "Type EMPTY to confirm: " c
        if [[ "$c" == "EMPTY" ]]; then
            rm -rf -- "${TRASH:?}"/*
            echo "Trash emptied."
        else
            echo "Aborted."
        fi
        exit 0 ;;
esac

ts="$(date +%Y%m%d-%H%M%S)"
batch="${TRASH}/${ts}-$$"
mkdir -p "$batch"

for src in "$@"; do
    if [[ ! -e "$src" && ! -L "$src" ]]; then
        echo "Skip (not found): $src" >&2
        continue
    fi
    abs="$(readlink -f -- "$src" 2>/dev/null || echo "$src")"
    # preserve original path inside the batch dir
    dest_dir="${batch}$(dirname -- "$abs")"
    mkdir -p "$dest_dir"
    mv -v -- "$src" "$dest_dir/"
done

echo ""
echo "Moved to: ${batch}"
echo "Run '$0 --list' to review or '$0 --empty' to permanently delete."
