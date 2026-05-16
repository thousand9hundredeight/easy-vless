#!/usr/bin/env bash
set -euo pipefail

#=============================================================================#
#                               LOAD CONFIG                                   #
#=============================================================================#

REPO_ROOT="$(dirname "$0")"
ENV_FILE="$REPO_ROOT/env"

if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  echo "Config file env not found. Run from repo root."
  exit 1
fi

export VLESS_SNI VLESS_INTERNAL_PORT VLESS_PUBLIC_PORT
export CONFIG_DIR CONFIG_FILE CREDS_FILE
export VLESS_USE_NGINX

#=============================================================================#
#                                EXECUTE                                      #
#=============================================================================#

./base.sh
./vless.sh
[[ "$VLESS_USE_NGINX" == "true" ]] && ./nginx.sh
[[ "$VLESS_INSTALL_3X_UI" == "true" ]] && ./3x-ui.sh
./vpnmon.sh

#=============================================================================#
#     		           UNIVERSAL INSTALLER                                #
#=============================================================================#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

cd "$(dirname "$0")"

#=============================================================================#
# 			       BASE SETUP                                     #
#=============================================================================#
echo -e "${GREEN}=== 1. BASE SETUP ===${NC}"
./setup-base.sh || die "Base setup failed"

#=============================================================================#
# 			    VLESS REALITY SETUP                               #
#=============================================================================#
echo -e "${GREEN}=== 2. VLESS REALITY SETUP ===${NC}"
./setup-vless.sh || die "VLESS Reality setup failed"

#=============================================================================#
# 			       NGINX SETUP                                    #
#=============================================================================#
echo -e "${GREEN}=== 3. NGINX SETUP ===${NC}"
./setup-nginx.sh || die "NGINX setup failed"

#=============================================================================#
# 			         VPNMON                                       #
#=============================================================================#
echo -e "${GREEN}=== 4. VPNMON MONITORING ===${NC}"
./setup-monitoring.sh || die "VPNMON setup failed"

#=============================================================================#
#				EXTRA TIPS                                    #
#=============================================================================#
echo -e "${GREEN}"
echo "installation completed."
echo "------------------------------------------------------------"
echo "VLESS user credentials stored in:"
echo "/root/vless-credentials.txt"
echo ""
echo "Monitoring tool:"
echo "vpnmon"
echo "------------------------------------------------------------"
echo -e "${NC}"

exit 0
