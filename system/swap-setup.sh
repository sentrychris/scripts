#!/usr/bin/env bash
set -euo pipefail

# Create or resize a swapfile. Idempotent.
# Usage: swap-setup.sh <size> [path]   e.g. swap-setup.sh 4G /swapfile

SIZE="${1:-2G}"
SWAPFILE="${2:-/swapfile}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if [[ -f "$SWAPFILE" ]]; then
    echo "Disabling existing ${SWAPFILE}..."
    swapoff "$SWAPFILE" 2>/dev/null || true
    rm -f "$SWAPFILE"
fi

echo "Allocating ${SIZE} at ${SWAPFILE}..."
if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "$SIZE" "$SWAPFILE"
else
    # Convert size to MB for dd fallback
    case "$SIZE" in
        *G) mb=$(( ${SIZE%G} * 1024 )) ;;
        *M) mb=${SIZE%M} ;;
        *)  echo "Use suffix G or M (e.g. 4G, 512M)." >&2; exit 1 ;;
    esac
    dd if=/dev/zero of="$SWAPFILE" bs=1M count="$mb" status=progress
fi

chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"
swapon "$SWAPFILE"

if ! grep -q "^${SWAPFILE} " /etc/fstab; then
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
    echo "Added ${SWAPFILE} to /etc/fstab"
fi

# Set sensible defaults if not already configured
sysctl_conf="/etc/sysctl.d/99-swap.conf"
if [[ ! -f "$sysctl_conf" ]]; then
    cat > "$sysctl_conf" <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
    sysctl -p "$sysctl_conf"
fi

echo ""
echo "Swap is active:"
swapon --show
free -h
