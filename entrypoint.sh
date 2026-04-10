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

# ── Validate UMAMI_HOST format (host:port, no special chars) ──
if ! echo "$UMAMI_HOST" | grep -qE '^[a-zA-Z0-9._-]+:[0-9]+$'; then
  echo "ERROR: UMAMI_HOST must be in host:port format (e.g. umami.railway.internal:3000)."
  echo "       Got: $UMAMI_HOST"
  exit 1
fi

# ── Generate .htpasswd from env vars ──
echo "Generating .htpasswd..."
htpasswd -cb /etc/nginx/.htpasswd "$AUTH_USER" "$AUTH_PASS"
chmod 600 /etc/nginx/.htpasswd

# ── Template the upstream address into nginx.conf ──
# Using awk instead of sed to avoid injection via delimiter characters
awk -v host="$UMAMI_HOST" '{gsub(/UMAMI_UPSTREAM/, host); print}' \
  /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp \
  && mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

echo "Proxy starting (upstream configured)"

# ── Hand off to nginx ──
exec "$@"
