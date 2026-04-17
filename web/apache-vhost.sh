#!/usr/bin/env bash
set -euo pipefail

# Create an Apache virtual host on port 80.
# Usage: apache-vhost.sh <domain> <relative-docroot>
# Example: apache-vhost.sh example.com example.com/public

ROOT_PATH="${ROOT_PATH:-/var/www}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if command -v dpkg >/dev/null 2>&1; then
    webserver="apache2"
    sites_available="/etc/${webserver}/sites-available"
    sites_enabled="/etc/${webserver}/sites-enabled"
    use_symlink=1
elif command -v rpm >/dev/null 2>&1; then
    webserver="httpd"
    sites_available="/etc/${webserver}/conf.d"
    sites_enabled=""
    use_symlink=0
else
    echo "Error: unsupported package manager (need dpkg or rpm)." >&2
    exit 1
fi

if ! command -v "$webserver" >/dev/null 2>&1 && ! command -v apachectl >/dev/null 2>&1; then
    echo "Error: Apache (${webserver}) not installed." >&2
    exit 1
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
<VirtualHost *:80>
    ServerName ${domain}
    ServerAlias www.${domain}
    DocumentRoot ${absolute_docroot}
    <Directory ${absolute_docroot}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/${webserver}/${domain}-error.log
    CustomLog /var/log/${webserver}/${domain}-access.log combined
</VirtualHost>
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

if ! apachectl configtest; then
    echo "Error: Apache config test failed — not reloading." >&2
    exit 1
fi

systemctl reload "${webserver}.service"
echo "Reloaded ${webserver}. Visit http://${domain}/"
