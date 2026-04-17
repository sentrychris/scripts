#!/usr/bin/env bash
set -euo pipefail

# Fresh-VPS hardening: create non-root user, install SSH key, disable
# password auth, enable ufw, install fail2ban + unattended upgrades.
# Usage: server-bootstrap.sh <username> <ssh-pubkey-file>

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

NEW_USER="${1:-}"
PUBKEY_FILE="${2:-}"

[[ -z "$NEW_USER"   ]] && read -rp "New sudo username: " NEW_USER
[[ -z "$PUBKEY_FILE" ]] && read -rp "Path to SSH public key file: " PUBKEY_FILE

if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo "Error: pubkey file not found: $PUBKEY_FILE" >&2
    exit 1
fi

if command -v apt >/dev/null 2>&1; then
    pm="apt"
    install="apt install -y"
    apt update
elif command -v dnf >/dev/null 2>&1; then
    pm="dnf"
    install="dnf install -y"
else
    echo "Error: unsupported package manager." >&2
    exit 1
fi

echo "==> Creating user ${NEW_USER}"
if ! id "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$NEW_USER"
    passwd -l "$NEW_USER" >/dev/null
fi

if [[ "$pm" == "apt" ]]; then
    usermod -aG sudo "$NEW_USER"
else
    usermod -aG wheel "$NEW_USER"
fi

echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEW_USER}"
chmod 440 "/etc/sudoers.d/${NEW_USER}"

echo "==> Installing SSH key"
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/${NEW_USER}/.ssh"
install -m 600 -o "$NEW_USER" -g "$NEW_USER" "$PUBKEY_FILE" "/home/${NEW_USER}/.ssh/authorized_keys"

echo "==> Hardening sshd"
sshd_conf="/etc/ssh/sshd_config.d/99-hardening.conf"
cat > "$sshd_conf" <<'EOF'
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding no
EOF
sshd -t
systemctl reload ssh 2>/dev/null || systemctl reload sshd

echo "==> Installing security packages"
$install ufw fail2ban unattended-upgrades

echo "==> Configuring ufw"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH 2>/dev/null || ufw allow 22/tcp
ufw --force enable

echo "==> Enabling fail2ban"
systemctl enable --now fail2ban

if [[ "$pm" == "apt" ]]; then
    echo "==> Enabling unattended-upgrades"
    dpkg-reconfigure -fnoninteractive unattended-upgrades || true
fi

echo ""
echo "Bootstrap complete. Verify SSH login as ${NEW_USER} BEFORE closing this session:"
echo "  ssh ${NEW_USER}@$(hostname -I | awk '{print $1}')"
