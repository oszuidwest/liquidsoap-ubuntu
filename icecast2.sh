#!/usr/bin/env bash

# Clear terminal
clear

# Download the functions library
if ! curl -s -o /tmp/functions.sh https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh; then
    echo -e  "*** Failed to download functions library. Please check your network connection! ***"
    exit 1
fi

# Source the functions file
source /tmp/functions.sh

# Configure environment
set_colors
are_we_root
is_this_linux
is_this_os_64bit
set_timezone Europe/Amsterdam

# Print introduction
clear
printf "********************************\n"
printf "ICECAST 2 INSTALLER\n"
printf "********************************\n"

# Collect user inputs
ask_user "HOSTNAME" "localhost" "Specify the host name (for example: icecast.zuidwestfm.nl. Enter it without http:// or www) please" "str"
ask_user "SOURCEPASS" "hackme" "Specify the source and relay password" "str"
ask_user "ADMINPASS" "hackme" "Specify the admin password" "str"
ask_user "LOCATED" "Earth" "Where is this server located (visible on admin pages)?" "str"
ask_user "ADMINMAIL" "root@localhost.local" "What's the admins e-mail (visible on admin pages and for let's encrypt)?" "email"
ask_user "PORT" "80" "Specify the port" "num"
ask_user "SSL" "n" "Do you want Let's Encrypt to get a certificate for this server? (y/n)" "y/n"

# Set environment variables
export DEBIAN_FRONTEND="noninteractive"

# Update and install packages
update_os silent
install_packages silent icecast2 certbot

# Generate initial icecast.xml configuration
ICECAST_XML="/etc/icecast2/icecast.xml"
cat <<EOF > "$ICECAST_XML"
<icecast>
    <location>$LOCATED</location>
    <admin>$ADMINMAIL</admin>
    <hostname>$HOSTNAME</hostname>

    <limits>
        <clients>1000</clients>
        <sources>10</sources>
    </limits>

    <authentication>
        <source-password>$SOURCEPASS</source-password>
        <relay-password>$SOURCEPASS</relay-password>
        <admin-user>admin</admin-user>
        <admin-password>$ADMINPASS</admin-password>
    </authentication>

    <listen-socket>
        <port>$PORT</port>
    </listen-socket>

    <http-headers>
        <header name="Access-Control-Allow-Origin" value="*" />
        <header name="X-Robots-Tag" value="noindex, noarchive" status="200" />
    </http-headers>

    <paths>
        <basedir>/usr/share/icecast2</basedir>
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <alias source="/zuidwest.stl" destination="/zuidwest.mp3"/>
        <alias source="/" destination="/status.xsl"/>
    </paths>

    <logging>
        <logsize>10000</logsize>
    </logging>
</icecast>
EOF

# Set capabilities
setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/icecast2

# Reload and restart Icecast service
systemctl enable icecast2
systemctl daemon-reload
systemctl restart icecast2

# SSL configuration
if [ "$SSL" = "y" ] && [ "$PORT" = "80" ]; then
    # Run Certbot to obtain SSL certificate
    certbot --text --agree-tos --email "$ADMINMAIL" --noninteractive --no-eff-email --webroot --webroot-path="/usr/share/icecast2/web" -d "$HOSTNAME" --deploy-hook "cat /etc/letsencrypt/live/$HOSTNAME/fullchain.pem /etc/letsencrypt/live/$HOSTNAME/privkey.pem > /usr/share/icecast2/icecast.pem && systemctl restart icecast2" certonly

    # Check if Certbot was successful
    if [ -f "/usr/share/icecast2/icecast.pem" ]; then
        # Update icecast.xml with SSL settings
        sed -i "/<paths>/a \
        \    <ssl-certificate>/usr/share/icecast2/icecast.pem</ssl-certificate>" "$ICECAST_XML"
        
        sed -i "/<\/listen-socket>/a \
        <listen-socket>\n\
            <port>443</port>\n\
            <ssl>1</ssl>\n\
        </listen-socket>" "$ICECAST_XML"

        # Restart Icecast to apply new configuration
        systemctl restart icecast2
    else
        echo "SSL certificate acquisition failed. Icecast will continue running on port 80."
    fi
else
    if [ "$SSL" = "y" ]; then
        echo "SSL setup is only possible when Icecast is running on port 80. Skipping SSL configuration."
    fi
fi
