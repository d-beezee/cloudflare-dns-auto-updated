#!/bin/bash

CONFIG_FILE="/usr/local/bin/auth.json"
CLOUDFLARE_API="https://api.cloudflare.com/client/v4"

# Funzione per stampare l'uso dello script
usage() {
  echo "Usage:"
  echo "  $0 -d <domain> -n <name> [-v <value>]"
  echo "Options:"
  echo "  -d <domain>    The root domain (e.g., domain.org)"
  echo "  -n <name>      The subdomain (e.g., cloud)"
  echo "  -v <value>     The IP address to set for the subdomain (optional)"
  exit 1
}

# Controlla che jq sia installato
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Install it and try again."
  exit 1
fi

# Carica le credenziali dal file di configurazione
if [[ ! -f $CONFIG_FILE ]]; then
  echo "Error: Configuration file $CONFIG_FILE not found."
  exit 1
fi

EMAIL=$(jq -r '.cloudflare.email' "$CONFIG_FILE")
API_KEY=$(jq -r '.cloudflare.key' "$CONFIG_FILE")
API_TOKEN=$(jq -r '.cloudflare.token' "$CONFIG_FILE")

# Controlla che le credenziali siano state lette
if [[ -z "$EMAIL" || -z "$API_KEY" || -z "$API_TOKEN" ]]; then
  echo "Error: Missing credentials in $CONFIG_FILE."
  exit 1
fi

# Analizza gli argomenti
while getopts "d:n:v:" opt; do
  case $opt in
    d) DOMAIN="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    v) VALUE="$OPTARG" ;;
    *) usage ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$NAME" ]]; then
  usage
fi

# Ottiene l'ID della zona
ZONE_ID=$(curl -s -X GET "$CLOUDFLARE_API/zones" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".result[] | select(.name==\"$DOMAIN\") | .id")

if [[ -z "$ZONE_ID" ]]; then
  echo "Error: Domain $DOMAIN not found in your Cloudflare account."
  exit 1
fi

# Ottiene i record DNS per il sottodominio
RECORD=$(curl -s -X GET "$CLOUDFLARE_API/zones/$ZONE_ID/dns_records?type=A&name=$NAME.$DOMAIN" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0]')

RECORD_ID=$(echo "$RECORD" | jq -r '.id')
RECORD_IP=$(echo "$RECORD" | jq -r '.content')

if [[ -z "$VALUE" ]]; then
  # Modalità di lettura: restituisce l'IP o None
  if [[ "$RECORD_ID" = "null" ]]; then
    echo "None"
  else
    echo "$RECORD_IP"
  fi
  exit 0
else
  # Modalità di scrittura: aggiorna o crea un nuovo record
  if [[ "$RECORD_ID" = "null" ]]; then
    # Crea un nuovo record
    RESPONSE=$(curl -s -X POST "$CLOUDFLARE_API/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$NAME.$DOMAIN\",\"content\":\"$VALUE\",\"ttl\":1,\"proxied\":false}")
  else
    # Aggiorna il record esistente
    RESPONSE=$(curl -s -X PUT "$CLOUDFLARE_API/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$NAME.$DOMAIN\",\"content\":\"$VALUE\",\"ttl\":1,\"proxied\":false}")
  fi

  SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
  if [[ "$SUCCESS" == "true" ]]; then
    echo "Operation successful for $NAME.$DOMAIN with IP $VALUE"
  else
    echo "Error: $(echo "$RESPONSE" | jq -r '.errors[] | .message')"
    exit 1
  fi
fi
