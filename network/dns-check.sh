#!/usr/bin/env bash
set -euo pipefail

# Compare DNS answers from several resolvers for a domain.
# Usage: dns-check.sh <domain> [record-type ...]

DOMAIN="${1:-}"
shift || true
TYPES=("$@")
[[ ${#TYPES[@]} -eq 0 ]] && TYPES=(A AAAA MX NS TXT CAA)

if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain> [record-type ...]" >&2
    exit 1
fi

if ! command -v dig >/dev/null 2>&1; then
    echo "Error: dig not installed (apt install dnsutils)." >&2
    exit 1
fi

RESOLVERS=(
    "1.1.1.1#Cloudflare"
    "8.8.8.8#Google"
    "9.9.9.9#Quad9"
    "208.67.222.222#OpenDNS"
)

# Find authoritative server too
AUTH_NS="$(dig +short NS "$DOMAIN" | head -n1)"
[[ -n "$AUTH_NS" ]] && RESOLVERS+=("${AUTH_NS%.}#Authoritative")

for type in "${TYPES[@]}"; do
    echo "==> ${DOMAIN} ${type}"
    for r in "${RESOLVERS[@]}"; do
        ip="${r%%#*}"
        name="${r##*#}"
        ans="$(dig +short +time=3 +tries=1 "@${ip}" "$type" "$DOMAIN" 2>/dev/null | sort | paste -sd ' ' -)"
        printf "  %-18s %s\n" "${name}" "${ans:-<none>}"
    done
    echo ""
done
