#!/bin/bash

source settings.conf

# Check if username argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 username"
    exit 1
fi

USERNAME="$1"
EMAIL="${USERNAME}@${SERVER_DOMAIN}"

# Check if the user already exists
if grep -q "\"email\": \"$EMAIL\"" "$CONFIG_FILE"; then
    echo "User with email $EMAIL already exists!"
    exit 1
fi

# Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "Creating client: $EMAIL"
echo "UUID: $UUID"

# Create temporary file with JSON block
TMP="/tmp/newclient.tmp"

cat > "$TMP" <<EOF
          {
            "id": "$UUID",
            "flow": "$FLOW",
            "level": 0,
            "email": "$EMAIL"
          },
EOF

# Insert the block after the "clients": [ line
sed -i "/\"clients\": \[/r $TMP" "$CONFIG_FILE"

rm "$TMP"

echo "Added to config.json"

# Generate VLESS URL
VLESS_URL="vless://$UUID@$SERVER_DOMAIN:$PORT?encryption=none&security=tls&flow=$FLOW&sni=$SERVER_DOMAIN&fp=$FINGERPRINT#$USERNAME"

USER_CONF="$USERS_DIR/$USERNAME.conf"
echo "$VLESS_URL" > "$USER_CONF"

echo "Created file $USER_CONF"

# Display QR code in terminal
echo
qrencode -t ANSIUTF8 "$VLESS_URL"

# Restart docker container xray
docker restart xray

# Show xray logs
sleep 3
docker logs -n 10 xray
