#!/bin/sh

for secret in API_KEY POAPI_KEY POUSER_KEY; do
  if [ ! -f "/run/secrets/$secret" ]; then
    echo "Secret $secret missing" >&2
    exit 1
  fi
done

exec pwsh -NoLogo -NoProfile -File /scripts/run.ps1
