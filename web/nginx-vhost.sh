#!/usr/bin/env bash
set -euo pipefail

# Create an nginx virtual host on port 80.
# Usage: nginx-vhost.sh <domain> <relative-docroot>
# Example: nginx-vhost.sh example.com example.com/public

ROOT_PATH="${ROOT_PATH:-/var/www}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
    echo "Error: nginx not installed." >&2
    exit 1
fi

# Debian-style sites-available/enabled, fallback to conf.d on RHEL/others.
if [[ -d /etc/nginx/sites-available ]]; then
    sites_available="/etc/nginx/sites-available"
    sites_enabled="/etc/nginx/sites-enabled"
    use_symlink=1
else
    sites_available="/etc/nginx/conf.d"
    sites_enabled=""
    use_symlink=0
fi

domain="${1:-}"
relative_docroot="${2:-}"

[[ -z "$domain"           ]] && read -rp "Domain: "        domain
[[ -z "$relative_docroot" ]] && read -rp "Document Root: " relative_docroot

if [[ -z "$domain" || -z "$relative_docroot" ]]; then
    echo "Error: domain and document root are required." >&2
    exit 1
fi

available_conf="${sites_available}/${domain}.conf"
absolute_docroot="${ROOT_PATH}/${relative_docroot}"

if [[ -e "$available_conf" ]]; then
    echo "Error: vhost config already exists at ${available_conf}" >&2
    exit 1
fi

if [[ ! -d "$absolute_docroot" ]]; then
    echo "Warning: document root ${absolute_docroot} does not exist."
    read -rp "Create it? (y/N): " create
    if [[ "${create,,}" == "y" ]]; then
        install -d -m 755 "$absolute_docroot"
    fi
fi

cat > "$available_conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain} www.${domain};
    root ${absolute_docroot};
    index index.html index.htm index.php;

    access_log /var/log/nginx/${domain}-access.log;
    error_log  /var/log/nginx/${domain}-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
echo "Wrote ${available_conf}"

if [[ $use_symlink -eq 1 ]]; then
    enabled_conf="${sites_enabled}/${domain}.conf"
    if [[ ! -e "$enabled_conf" ]]; then
        ln -s "$available_conf" "$enabled_conf"
        echo "Enabled ${enabled_conf}"
    fi
fi

if ! grep -qE "^[^#]*[[:space:]]${domain}([[:space:]]|$)" /etc/hosts; then
    echo "127.0.0.1       ${domain}" >> /etc/hosts
    echo "Added ${domain} to /etc/hosts"
fi

if ! nginx -t; then
    echo "Error: nginx config test failed — not reloading." >&2
    exit 1
fi

systemctl reload nginx.service
echo "Reloaded nginx. Visit http://${domain}/"
