#!/bin/bash

CONFIG="xray/config.json"
USERS_DIR="xray/user_configs"

# ===== Settings =====
SERVER_DOMAIN="example.com"
PORT="443"
FLOW="xtls-rprx-vision"
FINGERPRINT="chrome"
# ====================

# Check if username argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 username"
    exit 1
fi

USERNAME="$1"
EMAIL="${USERNAME}@${SERVER_DOMAIN}"

# Check if the user already exists
if grep -q "\"email\": \"$EMAIL\"" "$CONFIG"; then
    echo "User with email $EMAIL already exists!"
    exit 1
fi

# Generate UUID
UUID=$(openssl rand -hex 16 | sed 's/\(..\)/\1-/4' | sed 's/-/-4/' | sed 's/-[89ab]/a/' | cut -c1-36 | sed 's/-$//')

echo "Creating client: $EMAIL"
echo "UUID: $UUID"

mkdir -p "$USERS_DIR"

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
sed -i "/\"clients\": \[/r $TMP" "$CONFIG"

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
