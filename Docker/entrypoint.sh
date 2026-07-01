#!/bin/sh
set -e  # Exit on error

# Validate secrets με πιο descriptive errors
for secret in API_KEY POAPI_KEY POUSER_KEY; do
  if [ ! -f "/run/secrets/$secret" ]; then
    echo "❌ Error: Secret $secret is missing in /run/secrets/" >&2
    echo "   Please ensure the secret is properly mounted" >&2
    exit 1
  fi

  # Check που το secret δεν είναι empty
  if [ ! -s "/run/secrets/$secret" ]; then
    echo "❌ Error: Secret $secret exists but is empty" >&2
    exit 1
  fi
done

# Read and export secrets so they are available in-memory to appuser
export API_KEY=$(cat /run/secrets/API_KEY | tr -d '\r\n' | xargs)
export POAPI_KEY=$(cat /run/secrets/POAPI_KEY | tr -d '\r\n' | xargs)
export POUSER_KEY=$(cat /run/secrets/POUSER_KEY | tr -d '\r\n' | xargs)

# Change to user directory για write access
cd /home/appuser/scripts

echo "✅ All secrets validated, starting BridgeWatcher..."
exec pwsh -NoLogo -NoProfile -File ./run.ps1