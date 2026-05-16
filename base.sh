#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "[ERR] Run as root"; exit 1; }

bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
root@happyaqua:~/easy-vless# cat base.sh
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

apt-get update

apt-get install -y \
  ca-certificates \
  curl \
  wget \
  unzip \
  openssl \
  ufw \
  tmux \
  htop \
  figlet

if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
fi

systemctl enable --now docker

ufw allow ssh >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

echo "Base setup completed."
