#!/bin/bash

SCRIPT="cloudflare-update"

# Funzione per stampare l'uso dello script
usage() {
    echo "Usage:"
    echo "  $0 -d <domain> -n <name>"
    echo "Options:"
    echo "  -d <domain>    The root domain (e.g., domain.org)"
    echo "  -n <name>      The subdomain (e.g., cloud)"
    exit 1
}

command -v $SCRIPT &>/dev/null || {
    echo "Error: Required script $SCRIPT not fousnd."
    exit 1
}


# Analizza gli argomenti
while getopts "d:n:" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        n) NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$DOMAIN" || -z "$NAME" ]]; then
    usage
fi

# Ottiene l'indirizzo IP corrente
CURRENT_IP=$(curl -s ifconfig.io)
if [[ -z "$CURRENT_IP" ]]; then
    echo "Error: Unable to fetch the current IP address."
    exit 1
fi

echo "Current IP: $CURRENT_IP"

# Ottiene l'IP del record DNS esistente
echo $SCRIPT -d "$DOMAIN" -n "$NAME"
EXISTING_IP=$($SCRIPT -d "$DOMAIN" -n "$NAME")
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to fetch existing DNS record."
    exit 1
fi

# Se EXISTING_IP è la stringa "None"
if [[ "$EXISTING_IP" = "None" ]]; then
    echo "No existing DNS record found for $NAME.$DOMAIN"
    echo "Creating new DNS record..."
    
    $SCRIPT -d "$DOMAIN" -n "$NAME" -v "$CURRENT_IP"
    if [[ $? -eq 0 ]]; then
        echo "DNS record created successfully."
    else
        echo "Error: Failed to create DNS record."
        exit 1
    fi
    
    exit 0
    
fi

echo "Existing DNS IP: $EXISTING_IP"

# Confronta gli indirizzi IP e aggiorna se necessario
if [[ "$CURRENT_IP" != "$EXISTING_IP" ]]; then
    echo "Updating DNS record for $NAME.$DOMAIN to $CURRENT_IP"
    $SCRIPT -d "$DOMAIN" -n "$NAME" -v "$CURRENT_IP"
    if [[ $? -eq 0 ]]; then
        echo "DNS record updated successfully."
    else
        echo "Error: Failed to update DNS record."
        exit 1
    fi
else
    echo "No update needed. DNS record is already up-to-date."
fi
