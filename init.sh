#!/bin/bash

source settings.conf


# Check if first user provided
if [ -z "$1" ]; then
    echo "Usage: $0 user"
    exit 1
fi

# Check if directory exists
if [ ! -d "$XRAY_DIR" ]; then
    echo "Directory $XRAY_DIR does not exist!"
    exit 1
fi


# Replace example.com with user domain in config.json
if [ -f "$XRAY_DIR/config.json" ]; then
    sed -i "s/example\.com/$SERVER_DOMAIN/g" $XRAY_DIR/config.json
    echo "Updated $XRAY_DIR/config.json with domain $SERVER_DOMAIN"
else
    echo "$XRAY_DIR/config.json not found!"
fi

# Replace example.com with user domain in Caddyfile
if [ -f "$XRAY_DIR/Caddyfile" ]; then
    sed -i "s/example\.com/$SERVER_DOMAIN/g" $XRAY_DIR/Caddyfile
    echo "Updated $XRAY_DIR/Caddyfile with domain $SERVER_DOMAIN"
else
    echo "$XRAY_DIR/Caddyfile not found!"
fi

USERNAME="$1"
EMAIL="${USERNAME}@${SERVER_DOMAIN}"

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
          }
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


# Start containers
echo "Start Docker containers..."
docker-compose up -d

echo "Done!"
