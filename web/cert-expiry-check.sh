#!/usr/bin/env bash
set -euo pipefail

# Check TLS cert expiry for a list of domains.
# Usage: cert-expiry-check.sh [-w days] [-f domains.txt] [domain ...]

WARN_DAYS="${WARN_DAYS:-30}"
DOMAIN_FILE=""
DOMAINS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warn) WARN_DAYS="$2"; shift 2 ;;
        -f|--file) DOMAIN_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-w days] [-f domains.txt] [domain ...]"
            exit 0 ;;
        *) DOMAINS+=("$1"); shift ;;
    esac
done

if [[ -n "$DOMAIN_FILE" ]]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -n "$line" ]] && DOMAINS+=("$line")
    done < "$DOMAIN_FILE"
fi

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    echo "No domains provided." >&2
    exit 1
fi

now_epoch=$(date +%s)
exit_code=0

printf "%-40s %-12s %s\n" "DOMAIN" "DAYS LEFT" "EXPIRES"
printf "%-40s %-12s %s\n" "------" "---------" "-------"

for d in "${DOMAINS[@]}"; do
    host="${d%%:*}"
    port="${d##*:}"
    [[ "$port" == "$d" ]] && port=443

    expiry=$(echo | timeout 10 openssl s_client -servername "$host" -connect "${host}:${port}" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | cut -d= -f2 || true)

    if [[ -z "$expiry" ]]; then
        printf "%-40s %-12s %s\n" "$d" "ERROR" "could not fetch cert"
        exit_code=1
        continue
    fi

    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    flag=""
    if (( days_left < 0 )); then
        flag=" EXPIRED"
        exit_code=1
    elif (( days_left < WARN_DAYS )); then
        flag=" WARN"
        exit_code=1
    fi

    printf "%-40s %-12s %s%s\n" "$d" "$days_left" "$expiry" "$flag"
done

exit $exit_code
