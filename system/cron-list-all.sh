#!/usr/bin/env bash
set -euo pipefail

# Dump every scheduled job on this host: per-user crontabs,
# /etc/cron.* directories, and systemd timers.

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

echo "==================================================="
echo " Per-user crontabs"
echo "==================================================="
while IFS=: read -r user _ uid _ _ _ shell; do
    [[ "$shell" =~ (nologin|false)$ ]] && continue
    ct="$(crontab -u "$user" -l 2>/dev/null || true)"
    if [[ -n "$ct" ]]; then
        echo ""
        echo "--- $user ---"
        echo "$ct"
    fi
done < /etc/passwd

echo ""
echo "==================================================="
echo " System cron files"
echo "==================================================="
for f in /etc/crontab /etc/cron.d/*; do
    [[ -f "$f" ]] || continue
    echo ""
    echo "--- $f ---"
    grep -vE '^\s*(#|$)' "$f" || true
done

echo ""
echo "==================================================="
echo " /etc/cron.{hourly,daily,weekly,monthly}"
echo "==================================================="
for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    [[ -d "$d" ]] || continue
    entries="$(ls -1 "$d" 2>/dev/null)"
    if [[ -n "$entries" ]]; then
        echo ""
        echo "--- $d ---"
        echo "$entries" | sed 's/^/  /'
    fi
done

echo ""
echo "==================================================="
echo " systemd timers"
echo "==================================================="
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-timers --all --no-pager
fi

echo ""
echo "==================================================="
echo " anacron jobs (if present)"
echo "==================================================="
if [[ -f /etc/anacrontab ]]; then
    grep -vE '^\s*(#|$)' /etc/anacrontab || true
else
    echo "(no /etc/anacrontab)"
fi
