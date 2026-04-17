#!/usr/bin/env bash
set -euo pipefail

# Show every authorized_keys entry on this host, by user.
# Flags weak/legacy key types.

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root to read every user's authorized_keys." >&2
    exit 1
fi

weak_re='^ssh-(rsa1|dss)|^ssh-rsa .{0,360}[^A-Za-z0-9+/=]'

while IFS=: read -r user _ uid _ _ home _; do
    [[ $uid -lt 100 && "$user" != "root" ]] && continue
    [[ ! -d "$home" ]] && continue

    for f in "$home/.ssh/authorized_keys" "$home/.ssh/authorized_keys2"; do
        [[ -f "$f" ]] || continue

        printf "\n=== %s  (%s)\n" "$user" "$f"

        perm="$(stat -c '%a %U:%G' "$f")"
        echo "    perms: $perm"

        # Iterate keys, get fingerprints + comments
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            fp="$(ssh-keygen -lf <(echo "$line") 2>/dev/null || echo '?')"
            warn=""
            [[ "$line" =~ ^ssh-rsa ]] && {
                bits="$(echo "$fp" | awk '{print $1}')"
                [[ "$bits" =~ ^[0-9]+$ && "$bits" -lt 3072 ]] && warn=" [WEAK: ${bits}-bit RSA]"
            }
            [[ "$line" =~ ^(ssh-dss|ssh-rsa1) ]] && warn=" [LEGACY KEY TYPE]"
            echo "    $fp$warn"
        done < "$f"
    done
done < /etc/passwd

echo ""
echo "==> sshd allow/deny directives"
grep -EH '^(AllowUsers|AllowGroups|DenyUsers|DenyGroups|PermitRootLogin|PasswordAuthentication)' \
    /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
