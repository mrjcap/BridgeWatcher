#!/bin/sh
set -e  # Exit on error

resolve_secret() {
  lower_path="/run/secrets/$1"
  upper_path="/run/secrets/$2"
  if [ -f "$lower_path" ]; then
    secret_path="$lower_path"
  elif [ -f "$upper_path" ]; then
    secret_path="$upper_path"
  else
    echo "❌ Error: Secret $1 is missing in /run/secrets/" >&2
    echo "   Please ensure the secret is properly mounted" >&2
    exit 1
  fi

  if [ ! -s "$secret_path" ]; then
    echo "❌ Error: Secret $secret_path exists but is empty" >&2
    exit 1
  fi

  tr -d '\r\n' < "$secret_path"
}

# Read and export secrets so they are available in-memory to appuser
API_KEY=$(resolve_secret api_key API_KEY)
POAPI_KEY=$(resolve_secret pushover_token PUSHOVER_TOKEN)
POUSER_KEY=$(resolve_secret pushover_user PUSHOVER_USER)
export API_KEY POAPI_KEY POUSER_KEY

# Change to user directory για write access
cd /home/appuser/scripts

echo "✅ All secrets validated, starting BridgeWatcher..."
exec pwsh -NoLogo -NoProfile -File ./run.ps1
