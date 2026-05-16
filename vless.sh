#!/usr/bin/env bash
set -euo pipefail

die() { echo "[ERR] $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  die "env file not found: $ENV_FILE"
fi

: "${CONTAINER_NAME:?CONTAINER_NAME is required in .env}"
: "${IMAGE_NAME:?IMAGE_NAME is required in .env}"
: "${VLESS_SNI:?VLESS_SNI is required in .env}"
: "${VLESS_INTERNAL_PORT:?VLESS_INTERNAL_PORT is required in .env}"
: "${VLESS_PUBLIC_PORT:?VLESS_PUBLIC_PORT is required in .env}"
: "${CONFIG_DIR:?CONFIG_DIR is required in .env}"
: "${CONFIG_FILE:?CONFIG_FILE is required in .env}"
: "${CREDS_FILE:?CREDS_FILE is required in .env}"

mkdir -p "$CONFIG_DIR"

VLESS_KEYS="$(docker run --rm "$IMAGE_NAME" x25519 2>&1)"
VLESS_PRIVATE_KEY="$(echo "$VLESS_KEYS" | grep -i "private" | awk '{print $NF}')"
VLESS_PUBLIC_KEY="$(echo "$VLESS_KEYS"  | grep -i "public"  | awk '{print $NF}')"
VLESS_UUID="$(docker run --rm "$IMAGE_NAME" uuid 2>&1 | tr -d '[:space:]')"
VLESS_SHORT_ID="$(openssl rand -hex 8)"

[[ -n "$VLESS_PRIVATE_KEY" ]] || die "Failed to generate private key"
[[ -n "$VLESS_PUBLIC_KEY"  ]] || die "Failed to generate public key"
[[ -n "$VLESS_UUID"        ]] || die "Failed to generate UUID"
[[ -n "$VLESS_SHORT_ID"    ]] || die "Failed to generate short ID"

cat > "$CONFIG_FILE" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${VLESS_INTERNAL_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${VLESS_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${VLESS_SNI}:443",
          "xver": 0,
          "serverNames": ["${VLESS_SNI}"],
          "privateKey": "${VLESS_PRIVATE_KEY}",
          "shortIds": ["${VLESS_SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": { "domainStrategy": "UseIPv4" }
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

echo "[INFO] Checking for old container..."
if container_exists "$CONTAINER_NAME"; then
  echo "[INFO] Removing old container: $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME"
else
  echo "[INFO] No old container found, continuing..."
fi

echo "[INFO] Starting new container: $CONTAINER_NAME"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "0.0.0.0:${VLESS_PUBLIC_PORT}:${VLESS_INTERNAL_PORT}" \
  -v "$CONFIG_FILE:/etc/xray/config.json:ro" \
  "$IMAGE_NAME" \
  run -c /etc/xray/config.json

ufw allow "${VLESS_PUBLIC_PORT}/tcp" >/dev/null 2>&1 || true

SERVER_IP="$(
  curl -s --connect-timeout 5 ifconfig.me 2>/dev/null ||
  curl -s --connect-timeout 5 api.ipify.org 2>/dev/null ||
  hostname -I | awk '{print $1}'
)"

VLESS_LINK="vless://${VLESS_UUID}@${SERVER_IP}:${VLESS_PUBLIC_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${VLESS_SNI}&fp=chrome&pbk=${VLESS_PUBLIC_KEY}&sid=${VLESS_SHORT_ID}&type=tcp#easy-vless"

cat > "$CREDS_FILE" <<EOF
=== Easy VLESS Credentials — $(date) ===

SERVER IP:  $SERVER_IP
Container:  $CONTAINER_NAME
Image:      $IMAGE_NAME

--- VLESS Reality ---
UUID:       $VLESS_UUID
Public key: $VLESS_PUBLIC_KEY
Short ID:   $VLESS_SHORT_ID
SNI:        $VLESS_SNI
Port:       $VLESS_PUBLIC_PORT
Link:       $VLESS_LINK
EOF

chmod 600 "$CREDS_FILE"

echo "VLESS Reality setup completed."
