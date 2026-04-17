#!/usr/bin/env bash
set -euo pipefail

# Top sources of failed SSH logins.
# Usage: failed-logins.sh [--since "2 days ago"] [--top 20] [--ban]
# --ban prints fail2ban-client commands for the worst offenders.

SINCE="${SINCE:-1 day ago}"
TOP=20
BAN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="$2"; shift 2 ;;
        --top)   TOP="$2"; shift 2 ;;
        --ban)   BAN=1; shift ;;
        -h|--help)
            echo 'Usage: $0 [--since "1 day ago"] [--top 20] [--ban]'
            exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root to read auth logs." >&2
    exit 1
fi

get_log() {
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -u ssh.service -u sshd.service --since "$SINCE" --no-pager 2>/dev/null
    elif [[ -f /var/log/auth.log ]]; then
        cat /var/log/auth.log
    elif [[ -f /var/log/secure ]]; then
        cat /var/log/secure
    else
        echo "No auth log source found." >&2
        exit 1
    fi
}

echo "==> Top ${TOP} source IPs (failed logins since ${SINCE})"
get_log | grep -E 'Failed password|Invalid user|Connection closed by authenticating user' \
    | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | awk '{print $2}' \
    | sort | uniq -c | sort -rn | head -n "$TOP" \
    | awk '{printf "  %-6d %s\n", $1, $2}'

echo ""
echo "==> Top ${TOP} attempted usernames"
get_log | grep -E 'Failed password|Invalid user' \
    | grep -oE '(Failed password for (invalid user )?[^ ]+|Invalid user [^ ]+)' \
    | awk '{print $NF}' \
    | sort | uniq -c | sort -rn | head -n "$TOP" \
    | awk '{printf "  %-6d %s\n", $1, $2}'

if [[ $BAN -eq 1 ]]; then
    echo ""
    echo "==> fail2ban ban commands for top offenders"
    get_log | grep -E 'Failed password|Invalid user' \
        | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
        | awk '{print $2}' \
        | sort | uniq -c | sort -rn | head -n "$TOP" \
        | awk '{print "  fail2ban-client set sshd banip " $2}'
fi
