#!/usr/bin/env bash
set -euo pipefail

# Generate a new SSH key, install it on a remote host, verify it works,
# then optionally remove the old key from the remote authorized_keys.
# Usage: ssh-key-rotate.sh <user@host> [old-key-path] [new-key-path]

TARGET="${1:-}"
OLD_KEY="${2:-$HOME/.ssh/id_ed25519}"
NEW_KEY="${3:-$HOME/.ssh/id_ed25519.new}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <user@host> [old-key] [new-key]" >&2
    exit 1
fi

if [[ ! -f "$OLD_KEY" ]]; then
    echo "Error: old key not found: $OLD_KEY" >&2
    exit 1
fi

if [[ -e "$NEW_KEY" ]]; then
    echo "Error: new key path already exists: $NEW_KEY" >&2
    echo "Pick a different path or delete it first." >&2
    exit 1
fi

echo "==> Verifying current key works against ${TARGET}"
if ! ssh -i "$OLD_KEY" -o BatchMode=yes -o ConnectTimeout=10 \
        "$TARGET" true; then
    echo "Error: cannot log in with the old key — aborting." >&2
    exit 1
fi

echo "==> Generating new ed25519 key at ${NEW_KEY}"
ssh-keygen -t ed25519 -f "$NEW_KEY" -C "rotated-$(date +%Y%m%d)-$(hostname)"

echo "==> Installing new key on ${TARGET}"
ssh -i "$OLD_KEY" "$TARGET" \
    "umask 077 && mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" \
    < "${NEW_KEY}.pub"

echo "==> Verifying new key works"
if ! ssh -i "$NEW_KEY" -o BatchMode=yes -o ConnectTimeout=10 \
        "$TARGET" true; then
    echo "Error: new key does not work — leaving old key in place." >&2
    exit 1
fi
echo "New key OK."

echo ""
read -rp "Remove old key from remote authorized_keys? (y/N): " c
if [[ "${c,,}" != "y" ]]; then
    echo "Old key left on remote. Done."
    exit 0
fi

old_pub="$(cat "${OLD_KEY}.pub")"
old_field2="$(awk '{print $2}' "${OLD_KEY}.pub")"

# Remove the line containing the old key's base64 field. Backup first.
ssh -i "$NEW_KEY" "$TARGET" "
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.pre-rotate.\$(date +%Y%m%d-%H%M%S)
    grep -vF '${old_field2}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp
    mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
"

echo "==> Confirming new key still works after removal"
ssh -i "$NEW_KEY" -o BatchMode=yes "$TARGET" true
echo "Done. Remote backup: ~/.ssh/authorized_keys.pre-rotate.*"
echo "Local old key files (${OLD_KEY}, ${OLD_KEY}.pub) left intact — delete manually when sure."
