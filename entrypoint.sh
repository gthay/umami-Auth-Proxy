#!/bin/sh
set -e

# ── Validate required env vars ──
if [ -z "$AUTH_USER" ] || [ -z "$AUTH_PASS" ]; then
  echo "ERROR: AUTH_USER and AUTH_PASS environment variables must be set."
  exit 1
fi

if [ -z "$UMAMI_HOST" ]; then
  echo "ERROR: UMAMI_HOST environment variable must be set (e.g. umami.railway.internal:3000)."
  exit 1
fi

# ── Generate .htpasswd from env vars ──
echo "Generating .htpasswd for user: $AUTH_USER"
htpasswd -cb /etc/nginx/.htpasswd "$AUTH_USER" "$AUTH_PASS"

# ── Template the upstream address into nginx.conf ──
sed -i "s|UMAMI_UPSTREAM|${UMAMI_HOST}|g" /etc/nginx/nginx.conf

echo "Proxy starting → upstream: $UMAMI_HOST"

# ── Hand off to nginx ──
exec "$@"
