#!/usr/bin/env bash
set -euo pipefail

#=============================================================================#
#             EASY VLESS PARAMS! You can run this monthly via cron!           #
#=============================================================================#

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/env"

SNI_DOMAINS=(
  "dl.google.com"
  "time.google.com"
  "apple.com"
  "microsoft.com"
)

VLESS_SNI="${SNI_DOMAINS[RANDOM % ${#SNI_DOMAINS[@]}]}"

sed -i "s/^VLESS_SNI=.*/VLESS_SNI=\"$VLESS_SNI\"/" "$ENV_FILE"

cd "$REPO_ROOT"
./easy-instll.sh

# 0 0 1 * * ~./params.sh <------ CRON exmaple #
