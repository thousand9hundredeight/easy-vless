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

apt-get install -y -qq nginx

cat > /etc/nginx/sites-available/vless-nginx.conf <<EOF
server {
    listen 443 ssl http2;
    server_name ${VLESS_SNI};

    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:${VLESS_INTERNAL_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vless-nginx.conf /etc/nginx/sites-enabled/vless-nginx.conf
nginx -t
systemctl restart nginx

echo "NGINX setup completed."
