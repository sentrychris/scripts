#!/usr/bin/env bash

[[ "$(whoami)" != 'root' ]] &&
{
    echo "This script requires sudo privileges"
    exit 1;
}

[[ -x "$(command -v rpm)" ]] &&
{
    webserver="httpd"
    webuser="apache"
}

[[ -x "$(command -v dpkg)" ]] &&
{
    webserver="apache2"
    webuser="www-data"
}

user=webuser
group=webuser
rootpath="/var/www/"

sitesavailable="/etc/$webserver/sites-available/"
sitesenabled="/etc/$webserver/sites-enabled/"

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
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $absolutedocroot
    <Directory $absolutedocroot>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride all
            Require all granted
    </Directory>
    ErrorLog /var/log/$webserver/$domain-error.log
    CustomLog /var/log/$webserver/$domain-access.log combined
</VirtualHost>
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
systemctl restart $webserver.service
