#!/usr/bin/env bash
set -euo pipefail

# Issue a Let's Encrypt cert via certbot, auto-detect webserver.
# Usage: letsencrypt-issue.sh <domain> [extra-domain ...] -e <email>

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
    echo "certbot not installed. Install it first:"
    if command -v apt >/dev/null 2>&1; then
        echo "  apt install certbot python3-certbot-nginx python3-certbot-apache"
    elif command -v dnf >/dev/null 2>&1; then
        echo "  dnf install certbot python3-certbot-nginx python3-certbot-apache"
    fi
    exit 1
fi

domains=()
email=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--email) email="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 <domain> [extra-domain ...] -e <email>"
            exit 0 ;;
        *) domains+=("$1"); shift ;;
    esac
done

if [[ ${#domains[@]} -eq 0 ]]; then
    read -rp "Primary domain: " d
    domains=("$d")
fi
if [[ -z "$email" ]]; then
    read -rp "Email for renewal notices: " email
fi

plugin=""
if systemctl is-active --quiet nginx; then
    plugin="--nginx"
elif systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    plugin="--apache"
else
    echo "No active webserver detected — falling back to standalone (port 80 must be free)."
    plugin="--standalone"
fi

d_args=()
for d in "${domains[@]}"; do
    d_args+=(-d "$d")
done

certbot $plugin \
    --non-interactive --agree-tos \
    -m "$email" \
    --redirect \
    "${d_args[@]}"

echo "Cert issued. Renewal handled by the certbot.timer systemd unit."
systemctl list-timers certbot.timer --no-pager 2>/dev/null || true
