#!/bin/bash

# Controlla se l'utente è root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

UPDATE_SCRIPT_PATH="/usr/local/bin/cloudflare-auto-update"

cp script.sh /usr/local/bin/cloudflare-update
chmod +x /usr/local/bin/cloudflare-update

cp update.sh $UPDATE_SCRIPT_PATH
chmod +x $UPDATE_SCRIPT_PATH

# Variabili
SERVICE_FILE="/etc/systemd/system/cfupdater.service"
TIMER_FILE="/etc/systemd/system/cfupdater.timer"
AUTH_FILE="/usr/local/bin/auth.json"

# Input utente
read -p "Enter the root domain (e.g., domain.org): " DOMAIN
read -p "Enter the subdomain (e.g., cloud): " NAME
read -p "Enter your Cloudflare email: " CLOUDFLARE_EMAIL
read -p "Enter your Cloudflare API key: " CLOUDFLARE_KEY
read -p "Enter your Cloudflare API token: " CLOUDFLARE_TOKEN


# Crea il file auth.json
echo "Creating Cloudflare authentication file at $AUTH_FILE..."
cat <<EOF > "$AUTH_FILE"
{
    "cloudflare": {
        "email": "$CLOUDFLARE_EMAIL",
        "key": "$CLOUDFLARE_KEY",
        "token": "$CLOUDFLARE_TOKEN"
    }
}
EOF

chmod 600 "$AUTH_FILE"

# Crea il file di servizio
echo "Creating service file at $SERVICE_FILE..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Cloudflare DNS Auto-Updater
After=network.target

[Service]
ExecStart=$UPDATE_SCRIPT_PATH -d $DOMAIN -n $NAME
Restart=on-failure
EOF

# Crea il file del timer
echo "Creating timer file at $TIMER_FILE..."
cat <<EOF > "$TIMER_FILE"
[Unit]
Description=Run Cloudflare DNS Auto-Updater every 10 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
Unit=cfupdater.service

[Install]
WantedBy=timers.target
EOF

# Ricarica systemd e abilita il timer
echo "Reloading systemd, enabling, and starting the timer..."
systemctl daemon-reload
systemctl disable cfupdater.timer
systemctl stop cfupdater.timer
systemctl enable cfupdater.timer
systemctl start cfupdater.timer

echo "Installation complete!"
echo "Service: cfupdater.service"
echo "Timer: cfupdater.timer"
echo "Logs: journalctl -u cfupdater.service"
echo "Cloudflare credentials saved in $AUTH_FILE"
