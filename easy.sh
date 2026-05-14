#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Run the script as root"

# =============================================================================
# SETTINGS
# =============================================================================
APP_NAME="easy vless"
VLESS_SNI="dl.google.com"
VLESS_INTERNAL_PORT=8443
VLESS_PUBLIC_PORT=2443
CONFIG_DIR="/opt/vless"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CREDS_FILE="/root/vless-credentials.txt"

LOG_FILE="$(mktemp /tmp/easy-vless-log.XXXXXX)"
STAGE_FILE="$(mktemp /tmp/easy-vless-stage.XXXXXX)"
ANIM_PID=""
HEADER_H=0

# =============================================================================
# UI helpers
# =============================================================================
hide_cursor() { printf '\e[?25l'; }
show_cursor() { printf '\e[?25h'; }
save_cursor() { printf '\e[s'; }
restore_cursor() { printf '\e[u'; }
clear_line() { printf '\e[2K'; }
move_to() { tput cup "$1" "$2"; }

repeat_char() {
  local n="$1" ch="$2"
  printf "%*s" "$n" "" | tr ' ' "$ch"
}

banner_text() {
  if command -v figlet >/dev/null 2>&1; then
    figlet -f standard -w 200 "EASY VLESS"
  else
    cat <<'EOF'
███████  █████  ███████ ██    ██
██      ██   ██ ██       ██  ██
█████   ███████ ███████    ████
██      ██   ██      ██     ██
███████ ██   ██ ███████     ██
⠄⠄⠄⠄⣠⣴⣿⣿⣿⣷⣦⡠⣴⣶⣶⣶⣦⡀⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⣴⣿⣿⣫⣭⣭⣭⣭⣥⢹⣟⣛⣛⣛⣃⣀⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄
⠄⣠⢸⣿⣿⣿⣿⢯⡓⢻⠿⠿⠷⡜⣯⠭⢽⠿⠯⠽⣀⠄⠄⠄⠄⠄⠄⠄⠄⠄
⣼⣿⣾⣿⣿⣿⣥⣝⠂⠐⠈⢸⠿⢆⠱⠯⠄⠈⠸⣛⡒⠄⠄⠄⠄⠄⠄⠄⠄⠄
⣿⣿⣿⣿⣿⣿⣿⣶⣶⣭⡭⢟⣲⣶⡿⠿⠿⠿⠿⠋⠄⠄⣴⠶⠶⠶⠶⠶⢶⡀
⣿⣿⣿⣿⣿⢟⣛⠿⢿⣷⣾⣿⣿⣿⣿⣿⣿⣿⣷⡄⠄⢰⠇⠄⠄⠄⠄⠄⠈⣧
⣿⣿⣿⣿⣷⡹⣭⣛⠳⠶⠬⠭⢭⣝⣛⣛⣛⣫⣭⡥⠄⠸⡄⣶⣶⣾⣿⣿⢇⡟
⠿⣿⣿⣿⣿⣿⣦⣭⣛⣛⡛⠳⠶⠶⠶⣶⣶⣶⠶⠄⠄⠄⠙⠮⣽⣛⣫⡵⠊⠁
⣍⡲⠮⣍⣙⣛⣛⡻⠿⠿⠿⠿⠿⠿⠿⠖⠂⠄⠄⠄⠄⠄⠄⠄⠄⣸⠄⠄⠄⠄
⣿⣿⣿⣶⣦⣬⣭⣭⣭⣝⣭⣭⣭⣴⣷⣦⡀⠄⠄⠄⠄⠄⠄⠠⠤⠿⠦⠤⠄⠄
██    ██ ██      ███████ ███████ ███████
██    ██ ██      ██      ██      ██
██    ██ ██      █████   ███████ ███████
 ██  ██  ██      ██           ██      ██
  ████   ███████ ███████ ███████ ███████
EOF
  fi
}

banner_height() {
  banner_text | wc -l | tr -d ' '
}

init_layout() {
  local h
  h="$(banner_height)"
  HEADER_H=$((h + 3))
}

pulse_color() {
  local n="$1"
  local palette=(39 45 51 50 49 48 84 120 156 120 84 48 49 50 51 45)
  printf '%s' "${palette[$((n % ${#palette[@]}))]}"
}

spinner_frame() {
  local n="$1"
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  printf '%s' "${frames[$((n % ${#frames[@]}))]}"
}

log() {
  printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >> "$LOG_FILE"
}

set_stage() {
  printf '%s' "$*" > "$STAGE_FILE"
}

draw_header() {
  local frame="${1:-0}"
  local cols stage row line color bar_w pos base left right

  cols="$(tput cols 2>/dev/null || echo 80)"
  init_layout

  stage="Preparing installer"
  [[ -f "$STAGE_FILE" ]] && stage="$(cat "$STAGE_FILE")"

  row=0
  while IFS= read -r line; do
    color="$(pulse_color $((frame + row * 2)))"
    move_to "$row" 0
    clear_line
    printf "  \e[1;38;5;%sm%s\e[0m" "$color" "$line"
    row=$((row + 1))
  done < <(banner_text)

  move_to "$row" 0
  clear_line
  printf "\e[38;5;%sm%s\e[0m" "$(pulse_color $((frame + 2)))" "$(repeat_char "$cols" '═')"
  row=$((row + 1))

  move_to "$row" 0
  clear_line
  printf "  \e[1;38;5;%sm%s\e[0m  %s" \
    "$(pulse_color $((frame + 4)))" "$(spinner_frame "$frame")" "$stage"
  row=$((row + 1))

  move_to "$row" 0
  clear_line
  bar_w=$((cols - 4))
  [[ $bar_w -lt 10 ]] && bar_w=10
  pos=$((frame % bar_w))
  base="$(printf '%*s' "$bar_w" '' | tr ' ' '─')"
  left="${base:0:pos}"
  right="${base:$((pos + 1))}"
  printf "  %s\e[1;38;5;%sm●\e[0m%s" "$left" "$(pulse_color $((frame + 6)))" "$right"
}

draw_logs() {
  local rows max_lines row

  rows="$(tput lines 2>/dev/null || echo 24)"
  init_layout

  max_lines=$((rows - HEADER_H - 1))
  [[ $max_lines -lt 5 ]] && max_lines=5

  row=$HEADER_H
  while [[ $row -lt $rows ]]; do
    move_to "$row" 0
    clear_line
    row=$((row + 1))
  done

  row=$HEADER_H
  while IFS= read -r line; do
    [[ $row -ge $rows ]] && break
    move_to "$row" 0
    clear_line
    printf "%s" "$line"
    row=$((row + 1))
  done < <(tail -n "$max_lines" "$LOG_FILE" 2>/dev/null || true)
}

render() {
  local frame="${1:-0}"
  save_cursor
  draw_header "$frame"
  draw_logs
  restore_cursor
}

start_animator() {
  set_stage "Preparing installer"
  hide_cursor
  clear
  init_layout
  (
    local i=0
    while :; do
      render "$i"
      i=$((i + 1))
      sleep 0.09
    done
  ) &
  ANIM_PID=$!
}

stop_animator() {
  if [[ -n "${ANIM_PID:-}" ]]; then
    kill "$ANIM_PID" 2>/dev/null || true
    wait "$ANIM_PID" 2>/dev/null || true
    ANIM_PID=""
  fi
}

cleanup() {
  local code=$?
  trap - EXIT INT TERM

  stop_animator
  show_cursor
  tput sgr0 2>/dev/null || true

  if [[ $code -ne 0 ]]; then
    echo
    echo "==================== INSTALL FAILED ===================="
    tail -n 40 "$LOG_FILE" 2>/dev/null || true
    echo "========================================================"
  fi

  rm -f "$LOG_FILE" "$STAGE_FILE"
  exit "$code"
}

trap cleanup EXIT INT TERM

run_step() {
  local title="$1"
  shift

  set_stage "$title"
  log "INFO  $title"
  if "$@" >>"$LOG_FILE" 2>&1; then
    log "OK    $title"
  else
    log "ERR   $title"
    return 1
  fi
}

# =============================================================================
# INSTALL
# =============================================================================
start_animator

run_step "Cleaning previous installation" bash -lc '
  systemctl stop xray 2>/dev/null || true
  systemctl disable xray 2>/dev/null || true
  rm -f /etc/systemd/system/xray.service.d/20-user.conf
  systemctl daemon-reload 2>/dev/null || true

  docker stop vless-reality 2>/dev/null || true
  docker rm   vless-reality 2>/dev/null || true

  rm -rf /opt/vless
'

run_step "Updating apt package lists" apt-get update -qq

run_step "Installing required packages" bash -lc '
  for pkg in ca-certificates curl wget unzip openssl ufw tmux htop figlet; do
    dpkg -s "$pkg" >/dev/null 2>&1 || apt-get install -y -qq "$pkg"
  done
'

run_step "Installing Docker" bash -lc '
  if ! command -v docker >/dev/null 2>&1; then
    apt-get install -y -qq docker.io
  fi
  systemctl enable --now docker
'

set_stage "Generating VLESS Reality keys"
log "INFO  Generating VLESS Reality keys"

VLESS_KEYS="$(docker run --rm ghcr.io/xtls/xray-core:latest x25519 2>&1)"
VLESS_PRIVATE_KEY="$(echo "$VLESS_KEYS" | grep -i "private" | awk '{print $NF}')"
VLESS_PUBLIC_KEY="$(echo "$VLESS_KEYS"  | grep -i "public"  | awk '{print $NF}')"
VLESS_UUID="$(docker run --rm ghcr.io/xtls/xray-core:latest uuid 2>&1 | tr -d '[:space:]')"
VLESS_SHORT_ID="$(openssl rand -hex 8)"

[[ -n "$VLESS_PRIVATE_KEY" ]] || die "Failed to get private key"
[[ -n "$VLESS_PUBLIC_KEY"  ]] || die "Failed to get public key"
[[ -n "$VLESS_UUID"        ]] || die "Failed to get UUID"

log "OK    UUID:      $VLESS_UUID"
log "OK    Short ID:  $VLESS_SHORT_ID"

run_step "Writing VLESS config" bash -lc "
  mkdir -p '${CONFIG_DIR}'
  cat > '${CONFIG_FILE}' <<EOF
{
  \"log\": { \"loglevel\": \"warning\" },
  \"inbounds\": [
    {
      \"listen\": \"0.0.0.0\",
      \"port\": ${VLESS_INTERNAL_PORT},
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"${VLESS_UUID}\",
            \"flow\": \"xtls-rprx-vision\"
          }
        ],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"show\": false,
          \"dest\": \"${VLESS_SNI}:443\",
          \"xver\": 0,
          \"serverNames\": [\"${VLESS_SNI}\"],
          \"privateKey\": \"${VLESS_PRIVATE_KEY}\",
          \"shortIds\": [\"${VLESS_SHORT_ID}\"]
        }
      },
      \"sniffing\": {
        \"enabled\": true,
        \"destOverride\": [\"http\", \"tls\"],
        \"routeOnly\": true
      }
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"tag\": \"direct\",
      \"settings\": { \"domainStrategy\": \"UseIPv4\" }
    },
    {
      \"protocol\": \"blackhole\",
      \"tag\": \"block\"
    }
  ],
  \"routing\": {
    \"domainStrategy\": \"IPIfNonMatch\",
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [\"geoip:private\"],
        \"outboundTag\": \"block\"
      }
    ]
  }
}
EOF
"

run_step "Starting VLESS Reality container" bash -lc "
  docker run -d \
    --name vless-reality \
    --restart unless-stopped \
    -p '0.0.0.0:${VLESS_PUBLIC_PORT}:${VLESS_INTERNAL_PORT}' \
    -v '${CONFIG_FILE}:/etc/xray/config.json:ro' \
    ghcr.io/xtls/xray-core:latest \
    run -c /etc/xray/config.json

  sleep 3
  docker ps --filter 'name=vless-reality' --filter 'status=running' | grep -q vless-reality
"

run_step "Configuring firewall" bash -lc "
  ufw allow ssh >/dev/null 2>&1 || true
  ufw allow ${VLESS_PUBLIC_PORT}/tcp >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
"

run_step "Installing vpnmon" bash -lc "
  mkdir -p /root/bin
  cat > /root/bin/vpnmon <<'EOF'
#!/usr/bin/env bash
SESSION=vpnmon
if tmux has-session -t \"\$SESSION\" 2>/dev/null; then
  tmux attach -t \"\$SESSION\"
  exit 0
fi
tmux new-session -d -s \"\$SESSION\" 'htop'
tmux new-window -t \"\$SESSION\":2 'docker logs -f vless-reality'
tmux rename-window -t \"\$SESSION\":2 'vless'
tmux new-window -t \"\$SESSION\":3 'ss -tlnp | grep 2443 || true; bash'
tmux rename-window -t \"\$SESSION\":3 'ports'
tmux select-window -t \"\$SESSION\":1
tmux attach -t \"\$SESSION\"
EOF
  chmod +x /root/bin/vpnmon
  grep -qxF 'export PATH=\"\$HOME/bin:\$PATH\"' /root/.bashrc || echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> /root/.bashrc
"

set_stage "Preparing final credentials"
log "INFO  Preparing final credentials"

SERVER_IP="$(
  curl -s --connect-timeout 5 ifconfig.me 2>/dev/null ||
  curl -s --connect-timeout 5 api.ipify.org 2>/dev/null ||
  hostname -I | awk '{print $1}'
)"

VLESS_LINK="vless://${VLESS_UUID}@${SERVER_IP}:${VLESS_PUBLIC_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${VLESS_SNI}&fp=chrome&pbk=${VLESS_PUBLIC_KEY}&sid=${VLESS_SHORT_ID}&type=tcp#easy-vless"

cat > "$CREDS_FILE" <<EOF
=== Easy VLESS Credentials — $(date) ===

SERVER IP: $SERVER_IP

--- VLESS Reality ---
UUID:       $VLESS_UUID
Public key: $VLESS_PUBLIC_KEY
Short ID:   $VLESS_SHORT_ID
SNI:        $VLESS_SNI
Port:       $VLESS_PUBLIC_PORT
Link:       $VLESS_LINK
EOF

chmod 600 "$CREDS_FILE"
log "OK    Credentials saved to ${CREDS_FILE}"

stop_animator
show_cursor
clear

echo -e "${GREEN}"
banner_text
echo -e "${NC}"
echo "============================================================"
echo -e "${GREEN}Easy VLESS installed successfully${NC}"
echo "============================================================"
echo
echo -e "${CYAN}Server IP:${NC}    ${SERVER_IP}"
echo -e "${CYAN}Port:${NC}         ${VLESS_PUBLIC_PORT}"
echo -e "${CYAN}SNI:${NC}          ${VLESS_SNI}"
echo -e "${CYAN}UUID:${NC}         ${VLESS_UUID}"
echo -e "${CYAN}Public key:${NC}   ${VLESS_PUBLIC_KEY}"
echo -e "${CYAN}Short ID:${NC}     ${VLESS_SHORT_ID}"
echo
echo -e "${CYAN}VLESS link:${NC}"
echo "${VLESS_LINK}"
echo
echo -e "${CYAN}Saved to:${NC}     ${CREDS_FILE}"
echo -e "${CYAN}Monitoring:${NC}   vpnmon"
echo
echo "Last install log lines:"
echo "------------------------------------------------------------"
tail -n 12 "$LOG_FILE" 2>/dev/null || true
echo "------------------------------------------------------------"