#!/usr/bin/env bash
set -euo pipefail

die() { echo "[ERR] $*" >&2; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  die "env file not found: $ENV_FILE"
fi

mkdir -p /root/bin

cat > /root/bin/vpnmon <<EOF
#!/usr/bin/env bash
SESSION=vpnmon
if tmux has-session -t "\$SESSION" 2>/dev/null; then
  tmux attach -t "\$SESSION"
  exit 0
fi
tmux new-session -d -s "\$SESSION" 'htop'
tmux new-window -t "\$SESSION":2 'docker logs -f ${CONTAINER_NAME}'
tmux rename-window -t "\$SESSION":2 'vless'
tmux new-window -t "\$SESSION":3 'ss -tlnp | grep -E "443|2443|8443" || true; bash'
tmux rename-window -t "\$SESSION":3 'ports'
tmux select-window -t "\$SESSION":1
tmux attach -t "\$SESSION"
EOF

chmod +x /root/bin/vpnmon
grep -qxF 'export PATH="$HOME/bin:$PATH"' /root/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> /root/.bashrc

echo "vpnmon installed."
