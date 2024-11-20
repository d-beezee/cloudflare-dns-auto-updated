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
AUTH_FILE="/usr/local/bin/auth.json"

# Input utente
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

echo "Cloudflare credentials saved in $AUTH_FILE"


./create-timer.sh

