#!/usr/bin/env bash
set -euo pipefail

#=============================================================================#
#                           3X-UI PANEL!                                      #
#=============================================================================#

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

# 3X-UI INSTLL #
curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh | bash

echo -e "${GREEN}"
echo "3X-UI installation completed."
echo "Access the panel via:"
echo "https://<your-server-ip>:<panel-port>/x..."
echo "Username: admin"
echo "Password: <your-password>"
echo "For safety, change panel port and password in /etc/3x-ui/config.json"
echo -e "${NC}"
