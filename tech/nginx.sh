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
#                               NGINX SETUP!                                  #
#=============================================================================#

[[ $EUID -ne 0 ]] && die "Run as root"

NGINX_PORT=443
VLESS_PORT=8443
VLESS_SNI="dl.google.com"

# Instll nginx #
apt-get install -y nginx

# Make CFG #
cat > /etc/nginx/sites-available/vless-nginx.conf <<EOF
server {
    listen ${NGINX_PORT} ssl http2;
    server_name ${VLESS_SNI};

    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:${VLESS_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Run CFG #
ln -s /etc/nginx/sites-available/vless-nginx.conf /etc/nginx/sites-enabled/

# Rerun nginx #
systemctl restart nginx

echo "NGINX setup completed."
