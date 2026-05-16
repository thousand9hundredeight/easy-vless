#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/env"

if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  echo "env file not found; run from repo root"
  exit 1
fi

#=============================================================================#
#			     VLESS SETUP!                                     #
#=============================================================================#

[[ $EUID -ne 0 ]] && die "Run as root"

VLESS_SNI="dl.google.com"
VLESS_INTERNAL_PORT=8443
VLESS_PUBLIC_PORT=443
CONFIG_DIR="/opt/vless"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# ALL KEYS #
VLESS_KEYS="$(docker run --rm ghcr.io/xtls/xray-core:latest x25519 2>&1)"
VLESS_PRIVATE_KEY="$(echo "$VLESS_KEYS" | grep -i "private" | awk '{print $NF}')"
VLESS_PUBLIC_KEY="$(echo "$VLESS_KEYS"  | grep -i "public"  | awk '{print $NF}')"
VLESS_UUID="$(docker run --rm ghcr.io/xtls/xray-core:latest uuid 2>&1 | tr -d '[:space:]')"
VLESS_SHORT_ID="$(openssl rand -hex 8)"

# Vless CFG #
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

# Docker run #
docker run -d \
  --name vless-reality \
  --restart unless-stopped \
  -p "0.0.0.0:${VLESS_PUBLIC_PORT}:${VLESS_INTERNAL_PORT}" \
  -v "$CONFIG_FILE:/etc/xray/config.json:ro" \
  ghcr.io/xtls/xray-core:latest \
  run -c /etc/xray/config.json

# UFW permission #
ufw allow ${VLESS_PUBLIC_PORT}/tcp >/dev/null 2>&1

echo "VLESS Reality setup completed."
