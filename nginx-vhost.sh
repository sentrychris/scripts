#!/usr/bin/env bash

[[ "$(whoami)" != 'root' ]] &&
{
    echo "This script requires sudo privileges"
    exit 1;
}

rootpath="/var/www/"
sitesavailable="/etc/nginx/sites-available/"
sitesenabled="/etc/nginx/sites-enabled/"

domain="$2"
relativedocroot="$3"

[[ -z "$domain" ]] &&
{
    read -p "Domain: " domain
}

[[ -z "$relativedocroot" ]] &&
{
    read -p "Document Root: " relativedocroot
}

availableconf="$sitesavailable$domain.conf"
enabledconf="$sitesenabled$domain.conf"
absolutedocroot="$rootpath$relativedocroot"

[[ -e "$availableconf" ]] &&
{
    echo "vhost already created."
    exit 1;
}

if ! cat << EOF > $availableconf
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    root $absolutedocroot;
    index index.html index.htm index.php;

    access_log /var/log/nginx/$domain-access.log;
    error_log  /var/log/nginx/$domain-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
then
    echo "error creating vhost."
else
    echo "success, new vhost created."
fi

cat << EOF >> /etc/hosts
127.0.0.1       $domain
EOF

ln -s "$availableconf" "$enabledconf"

if nginx -t; then
    systemctl reload nginx.service
else
    echo "nginx config test failed — not reloading."
    exit 1
fi
