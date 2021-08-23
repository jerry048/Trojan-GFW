#!/bin/bash
tput sgr0; clear

## Check Root Privilege
if [ $(id -u) -ne 0 ]; then 
    warn_1; echo  "This script needs root permission to run"; normal_4 
    exit 1 
fi

source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Miscellaneous/tput.sh)
need_input
read -p "Domain name with DNS A Record pointing to server's IP Address: " domain
read -p "Password of Trojan: " password
normal_2

## Update & install necessary packages
apt-get update && apt-get upgrade
apt-get install -qqy nginx trojan zip unzip certbot python3-certbot-nginx

## Set up nginx
systemctl enable nginx && systemctl start nginx
sed -i 's/server_name/server_name $domain/' /etc/nginx/sites-available/default
systemctl restart nginx

## Set up Web Server
wget https://github.com/jerry048/Trojan-GFW/raw/main/Sample-Website.zip && unzip Sample-Website.zip
cp -rf Sample-Website/ /var/www/html/
rm -r Sample-Website Sample-Website.zip

## Add SSL cert & configure it to renew automatically every 90 days
certbot certonly --nginx
echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
chmod -R +rx /etc/letsencrypt

## Set up Trojan
# SystemD service for Trojan
 cat << EOF >/etc/systemd/system/trojan.service
 [Unit]
Description=trojan
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service

[Service]
Type=simple
StandardError=journal
User=nobody
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/usr/bin/trojan /etc/trojan/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

# Configure trojan
cat << EOF>/etc/trojan/config.json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$password"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/letsencrypt/live/$domain/fullchain.pem",
        "key": "/etc/letsencrypt/live/$domain/privkey.pem",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
systemctl enable trojan && systemctl start trojan

## Tweaking
tput sgr0; clear
normal_1; echo "System Tweak"; warn_2

# Check Virtual Environment
systemd-detect-virt > /dev/null
if [ $? -eq 0 ]; then
	warn_1; echo "Virtualization is detected, part of the tweaking might not work"; warn_2
fi

source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/tweaking.sh)
CPU_Tweaking
NIC_Tweaking
Network_Other_Tweaking
kernel_Tweaking
while true; do
	need_input; read -p "Do you wish to install Tweaked BBR? (Y/N):" yn; normal_1
	case $yn in
		[Yy]* ) echo "Installing Tweaked BBR"; Tweaked_BBR; break;;
		[Nn]* ) echo "Skipping"; break;;
		* ) warn_1; echo "Please answer yes or no."; normal_2;;
	esac
done 

## Clear
tput sgr0; clear
normal_1; echo "Trojan-GFW installation completed"