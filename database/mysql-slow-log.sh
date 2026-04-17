#!/usr/bin/env bash
set -euo pipefail

# Toggle MySQL slow query log on/off and summarize it.
# Usage: mysql-slow-log.sh on [seconds]
#        mysql-slow-log.sh off
#        mysql-slow-log.sh status
#        mysql-slow-log.sh tail
#        mysql-slow-log.sh summary

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

cmd="${1:-status}"
threshold="${2:-1}"

slow_path="$(mysql -Nse "SELECT @@slow_query_log_file;" 2>/dev/null || echo '')"

case "$cmd" in
    on)
        mysql -e "SET GLOBAL slow_query_log = 'ON';
                  SET GLOBAL long_query_time = ${threshold};
                  SET GLOBAL log_queries_not_using_indexes = 'ON';"
        echo "Slow log enabled (threshold ${threshold}s)."
        echo "Log file: ${slow_path}"
        ;;
    off)
        mysql -e "SET GLOBAL slow_query_log = 'OFF';
                  SET GLOBAL log_queries_not_using_indexes = 'OFF';"
        echo "Slow log disabled."
        ;;
    status)
        mysql -t -e "SHOW VARIABLES WHERE Variable_name IN
            ('slow_query_log','long_query_time','slow_query_log_file',
             'log_queries_not_using_indexes');"
        ;;
    tail)
        if [[ -z "$slow_path" || ! -f "$slow_path" ]]; then
            echo "Slow log file not found." >&2
            exit 1
        fi
        tail -F "$slow_path"
        ;;
    summary)
        if [[ -z "$slow_path" || ! -f "$slow_path" ]]; then
            echo "Slow log file not found." >&2
            exit 1
        fi
        if ! command -v mysqldumpslow >/dev/null 2>&1; then
            echo "mysqldumpslow not installed." >&2
            exit 1
        fi
        echo "==> Top 10 slow queries by total time"
        mysqldumpslow -s t -t 10 "$slow_path"
        ;;
    *)
        echo "Usage: $0 {on [seconds]|off|status|tail|summary}" >&2
        exit 1 ;;
esac
