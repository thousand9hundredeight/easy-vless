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
#                             VPN MONITORING                                  #
#=============================================================================#

[[ $EUID -ne 0 ]] && die "Run as root"

mkdir -p /root/bin

cat > /root/bin/vpnmon <<'EOF'
#!/usr/bin/env bash
SESSION=vpnmon
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
  exit 0
fi
tmux new-session -d -s "$SESSION" 'htop'
tmux new-window -t "$SESSION":2 'docker logs -f vless-reality'
tmux rename-window -t "$SESSION":2 'vless'
tmux new-window -t "$SESSION":3 'ss -tlnp | grep 2443 || true; bash'
tmux rename-window -t "$SESSION":3 'ports'
tmux select-window -t "$SESSION":1
tmux attach -t "$SESSION"
EOF

chmod +x /root/bin/vpnmon

grep -qxF 'export PATH="$HOME/bin:$PATH"' /root/.bashrc || \
  echo 'export PATH="$HOME/bin:$PATH"' >> /root/.bashrc

echo "VPNMON setup completed."
