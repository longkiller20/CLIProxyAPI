#!/bin/sh
set -eu

# Render provides PORT; CLIProxyAPI reads its listener port from config.yaml.
: "${PORT:=10000}"
: "${CPA_API_KEY:?Missing CPA_API_KEY environment variable}"
: "${CPA_MANAGEMENT_SECRET:?Missing CPA_MANAGEMENT_SECRET environment variable}"

# The persistent disk is mounted at /data. Keep both config and provider credentials
# off the container's ephemeral filesystem so they survive redeploys and restarts.
mkdir -p /data/auths

if [ ! -f /data/config.yaml ]; then
  cp /CLIProxyAPI/config.example.yaml /data/config.yaml

  # Initialize secure credentials only once. Later starts preserve settings changed
  # through the management panel.
  sed -i 's/^  allow-remote: false$/  allow-remote: true/' /data/config.yaml
  sed -i "s|^  secret-key: \"\"$|  secret-key: \"${CPA_MANAGEMENT_SECRET}\"|" /data/config.yaml
  sed -i "s|\"your-api-key-1\"|\"${CPA_API_KEY}\"|" /data/config.yaml
  sed -i '/"your-api-key-2"/d; /"your-api-key-3"/d' /data/config.yaml
  sed -i 's|auth-dir: "~/.cli-proxy-api"|auth-dir: "/data/auths"|' /data/config.yaml
fi

# Update only server.port, allowing Render's assigned port to take precedence.
sed -i "/^server:/,/^[^#[:space:]]/ { s/^  port: [0-9][0-9]*$/  port: ${PORT}/; }" /data/config.yaml

cd /CLIProxyAPI
exec ./CLIProxyAPI --config /data/config.yaml
