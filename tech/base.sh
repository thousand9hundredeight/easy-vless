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

RED='\\033[0;31m'
GREEN='\\033[0;32m'
NC='\\033[0m'

die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run as root"

#=============================================================================#
#			          BASE!                                       #
#=============================================================================#

run_step() {
  local title="$1"
  shift
  echo "[$(date +'%H:%M:%S')] $title"
  if "$@"; then
    echo "[$(date +'%H:%M:%S')] $title: OK"
  else
    echo "[$(date +'%H:%M:%S')] $title: ERROR"
    exit 1
  fi
}

# Updating #
run_step "Updating apt package lists" apt-get update -qq

# Required packages #
run_step "Installing required packages" bash -lc '
  for pkg in ca-certificates curl wget unzip openssl ufw tmux htop figlet; do
    dpkg -s "$pkg" >/dev/null 2>&1 || apt-get install -y -qq "$pkg"
  done
'

# Docker #
run_step "Installing Docker" bash -lc '
  if ! command -v docker >/dev/null 2>&1; then
    apt-get install -y -qq docker.io
  fi
  systemctl enable --now docker
'

# UFW #
run_step "Configuring firewall" bash -lc "
  ufw allow ssh >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
"

echo "Base setup completed."
