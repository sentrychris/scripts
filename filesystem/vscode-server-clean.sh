#!/usr/bin/env bash
set -euo pipefail

# Prune old VS Code Server install directories. Each VS Code update leaves
# the previous Stable-<commithash>/ dir behind — only the newest is used
# after you reconnect.
# Usage: vscode-server-clean.sh [--apply] [--keep N] [--user NAME]
# Defaults: dry-run, keep newest 1, current user.

APPLY=0
KEEP=1
USER_NAME="${SUDO_USER:-$USER}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)  APPLY=1; shift ;;
        --keep)   KEEP="$2"; shift 2 ;;
        --user)   USER_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--apply] [--keep N] [--user NAME]"
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || (( KEEP < 1 )); then
    echo "Error: --keep must be a positive integer." >&2
    exit 1
fi

home="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if [[ -z "$home" || ! -d "$home" ]]; then
    echo "Error: home directory not found for user ${USER_NAME}." >&2
    exit 1
fi

servers_dir="${home}/.vscode-server/cli/servers"
if [[ ! -d "$servers_dir" ]]; then
    echo "No VS Code Server install found at ${servers_dir}"
    exit 0
fi

mapfile -t all < <(find "$servers_dir" -maxdepth 1 -mindepth 1 -type d -name 'Stable-*' -printf '%T@\t%p\n' \
    | sort -rn | cut -f2-)

total=${#all[@]}
if (( total <= KEEP )); then
    echo "Found ${total} server dir(s); keeping ${KEEP}. Nothing to prune."
    exit 0
fi

keep_list=("${all[@]:0:KEEP}")
prune_list=("${all[@]:KEEP}")

echo "==> Servers found: ${total}"
echo ""
echo "Keeping (newest ${KEEP}):"
for d in "${keep_list[@]}"; do
    printf "  %s  %s\n" "$(du -sh "$d" 2>/dev/null | cut -f1)" "$(basename "$d")"
done

echo ""
echo "Pruning (${#prune_list[@]}):"
freed=0
for d in "${prune_list[@]}"; do
    size_h="$(du -sh "$d" 2>/dev/null | cut -f1)"
    size_b="$(du -sb "$d" 2>/dev/null | cut -f1)"
    freed=$(( freed + ${size_b:-0} ))
    printf "  %s  %s\n" "$size_h" "$(basename "$d")"
done

echo ""
echo "Total to free: $(numfmt --to=iec "$freed" 2>/dev/null || echo "${freed}B")"

if [[ $APPLY -eq 0 ]]; then
    echo ""
    echo "(dry-run — re-run with --apply to actually delete)"
    exit 0
fi

echo ""
for d in "${prune_list[@]}"; do
    rm -rf -- "$d"
    echo "Removed $(basename "$d")"
done
echo "Done."
