#!/bin/sh
set -e

PROXY_MODE="${PROXY_MODE:-combined}"

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

case "$PROXY_MODE" in
  combined)
    NGINX_TEMPLATE="/etc/nginx/templates/nginx.conf"
    REQUIRE_AUTH=1
    REQUIRE_ALLOWLIST=0
    ;;
  admin)
    NGINX_TEMPLATE="/etc/nginx/templates/nginx.admin.conf"
    REQUIRE_AUTH=0
    REQUIRE_ALLOWLIST=1
    ;;
  collector)
    NGINX_TEMPLATE="/etc/nginx/templates/nginx.collect.conf"
    REQUIRE_AUTH=0
    REQUIRE_ALLOWLIST=0
    ;;
  *)
    echo "ERROR: PROXY_MODE must be one of: combined, admin, collector."
    echo "       Got: $PROXY_MODE"
    exit 1
    ;;
esac

if [ "$REQUIRE_AUTH" = "1" ]; then
  if [ -z "$AUTH_USER" ] || [ -z "$AUTH_PASS" ]; then
    echo "ERROR: AUTH_USER and AUTH_PASS environment variables must be set for PROXY_MODE=$PROXY_MODE."
    exit 1
  fi

  echo "Generating .htpasswd..."
  htpasswd -cb /etc/nginx/.htpasswd "$AUTH_USER" "$AUTH_PASS"
  chown root:nginx /etc/nginx/.htpasswd
  chmod 640 /etc/nginx/.htpasswd
fi

if [ "$REQUIRE_ALLOWLIST" = "1" ]; then
  if [ -z "$ADMIN_ALLOW_CIDRS" ]; then
    echo "ERROR: ADMIN_ALLOW_CIDRS must be set for PROXY_MODE=$PROXY_MODE."
    echo "       Example: 203.0.113.10,198.51.100.0/24"
    exit 1
  fi

  : > /etc/nginx/admin-allow.geo

  OLD_IFS=$IFS
  IFS=','
  set -- $ADMIN_ALLOW_CIDRS
  IFS=$OLD_IFS

  for cidr in "$@"; do
    cidr="$(echo "$cidr" | xargs)"

    if [ -z "$cidr" ]; then
      continue
    fi

    if ! echo "$cidr" | grep -qE '^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$'; then
      echo "ERROR: Invalid CIDR/IP in ADMIN_ALLOW_CIDRS: $cidr"
      exit 1
    fi

    echo "$cidr 1;" >> /etc/nginx/admin-allow.geo
  done
fi

# ── Template the upstream address into the selected nginx config ──
# Using awk instead of sed to avoid injection via delimiter characters
awk -v host="$UMAMI_HOST" '{gsub(/UMAMI_UPSTREAM/, host); print}' \
  "$NGINX_TEMPLATE" > /etc/nginx/nginx.conf.tmp \
  && mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

echo "Proxy starting (mode=$PROXY_MODE, upstream configured)"

# ── Hand off to nginx ──
exec "$@"
