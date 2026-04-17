#!/usr/bin/env bash
set -euo pipefail

# Inventory every sudo grant on this host.
# Highlights NOPASSWD and ALL=(ALL) entries.

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

red()    { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }

scan() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]] || return 0

    local perm owner
    perm="$(stat -c '%a' "$file")"
    owner="$(stat -c '%U:%G' "$file")"

    printf "\n=== %s  [perms %s, owner %s]\n" "$file" "$perm" "$owner"

    if [[ "$perm" != "440" && "$perm" != "400" ]]; then
        yellow "  WARN: perms should be 440 or 400" ; echo
    fi

    while IFS= read -r line; do
        # skip blanks/comments/Defaults
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*Defaults ]] && { echo "  $line"; continue; }

        if [[ "$line" =~ NOPASSWD ]]; then
            red   "  ! "; echo "$line"
        elif [[ "$line" =~ ALL=\(ALL ]]; then
            yellow "  * "; echo "$line"
        else
            echo "    $line"
        fi
    done < "$file"
}

scan /etc/sudoers
if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
        [[ "$(basename "$f")" == "README" ]] && continue
        scan "$f"
    done
fi

echo ""
echo "==> Members of admin groups"
for g in sudo wheel admin; do
    if getent group "$g" >/dev/null 2>&1; then
        printf "  %s: %s\n" "$g" "$(getent group "$g" | cut -d: -f4)"
    fi
done

echo ""
echo "Legend: $(red '!') NOPASSWD   $(yellow '*') ALL=(ALL)"
