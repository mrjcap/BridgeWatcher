#!/bin/sh
set -euo pipefail

get_secret() {
  local n=$1; local f="/run/secrets/$n"
  [[ -f $f ]] || { echo "Secret $n missing" >&2; exit 1; }
  head -c -1 "$f"
}
   API_KEY=$(get_secret API_KEY)
 POAPI_KEY=$(get_secret POAPI_KEY)
POUSER_KEY=$(get_secret POUSER_KEY)

exec pwsh -NoLogo -NoProfile -File /scripts/run.ps1 -ApiKey "$API_KEY" -PoApiKey  "$POAPI_KEY" -PoUserKey "$POUSER_KEY"