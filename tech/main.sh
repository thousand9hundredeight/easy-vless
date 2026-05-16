#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

[[ -f "$ENV_FILE" ]] || die "Config file not found: $ENV_FILE"

set -a
source "$ENV_FILE"
set +a

: "${VLESS_SNI:?VLESS_SNI is required}"
: "${VLESS_INTERNAL_PORT:?VLESS_INTERNAL_PORT is required}"
: "${VLESS_PUBLIC_PORT:?VLESS_PUBLIC_PORT is required}"
: "${CONFIG_DIR:?CONFIG_DIR is required}"
: "${CONFIG_FILE:?CONFIG_FILE is required}"
: "${CREDS_FILE:?CREDS_FILE is required}"

echo -e "${GREEN}=== 1. BASE SETUP ===${NC}"
"$SCRIPT_DIR/base.sh" || die "Base setup failed"

echo -e "${GREEN}=== 2. VLESS REALITY SETUP ===${NC}"
"$SCRIPT_DIR/vless.sh" || die "VLESS Reality setup failed"

if [[ "${VLESS_USE_NGINX:-false}" == "true" ]]; then
  echo -e "${GREEN}=== 3. NGINX SETUP ===${NC}"
  "$SCRIPT_DIR/nginx.sh" || die "NGINX setup failed"
fi

if [[ "${VLESS_INSTALL_3X_UI:-false}" == "true" ]]; then
  echo -e "${GREEN}=== 4. 3X-UI SETUP ===${NC}"
  "$SCRIPT_DIR/optional-3xui" || die "3X-UI setup failed"
fi

echo -e "${GREEN}=== 5. VPNMON MONITORING ===${NC}"
"$SCRIPT_DIR/vpnmon.sh" || die "VPNMON setup failed"

echo
echo "installation completed."
echo "------------------------------------------------------------"
echo "VLESS user credentials stored in:"
echo "$CREDS_FILE"
echo
echo "Monitoring tool:"
echo "vpnmon"
echo "------------------------------------------------------------"
