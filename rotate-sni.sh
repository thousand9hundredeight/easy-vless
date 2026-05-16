#!/usr/bin/env bash
set -euo pipefail

die() { echo "[ERR] $*" >&2; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

[[ -f "$ENV_FILE" ]] || die "env file not found: $ENV_FILE"

SNI_DOMAINS=(
  "dl.google.com"
  "time.google.com"
  "www.apple.com"
  "www.microsoft.com"
)

NEW_SNI="${SNI_DOMAINS[RANDOM % ${#SNI_DOMAINS[@]}]}"

sed -i "s|^VLESS_SNI=.*|VLESS_SNI=\"$NEW_SNI\"|" "$ENV_FILE"

echo "[INFO] VLESS_SNI updated to: $NEW_SNI"

cd "$SCRIPT_DIR"
./easy-instll.sh
