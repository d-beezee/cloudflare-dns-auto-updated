#!/bin/bash

# Controlla se l'utente è root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

UPDATE_SCRIPT_PATH="/usr/local/bin/cloudflare-auto-update"

# Input utente
read -p "Enter the root domain (e.g., domain.org): " DOMAIN
read -p "Enter the subdomain (e.g., cloud): " NAME

# Sostiuisce i caratteri non alfanumerici con un trattino
UNIQUE_ID=$(echo "$NAME" | tr -cd '[:alnum:]-')-$(echo "$DOMAIN" | tr -cd '[:alnum:]-')

# Variabili
SERVICE_NAME="cfupdater-$UNIQUE_ID"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
TIMER_FILE="/etc/systemd/system/$SERVICE_NAME.timer"


if [[ -f "$SERVICE_FILE" || -f "$TIMER_FILE" ]]; then
    echo "Service or timer file already exists for this domain and subdomain"
    exit 1
fi


echo "Creating timer for $DOMAIN.$NAME..."

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
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF

# Ricarica systemd e abilita il timer
echo "Reloading systemd, enabling, and starting the timer..."
systemctl daemon-reload
systemctl disable $SERVICE_NAME.timer 2>/dev/null
systemctl stop $SERVICE_NAME.timer 2>/dev/null
systemctl enable $SERVICE_NAME.timer
systemctl start $SERVICE_NAME.timer

echo "Installation complete!"
echo "Service: $SERVICE_NAME.service"
echo "Timer: $SERVICE_NAME.timer"
echo "Logs: journalctl -u $SERVICE_NAME.service"
