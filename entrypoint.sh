#!/usr/bin/env bash
set -e

CONF="${ODOO_RC:-/etc/odoo/odoo.conf}"
TMP_CONF="/tmp/odoo.conf"

cp "$CONF" "$TMP_CONF"
CONF="$TMP_CONF"

# Ensure [options] exists
if ! grep -q '^\[options\]' "$CONF"; then
  echo '[options]' >> "$CONF"
fi

# Apply DB connection settings from Render env vars
if [ -n "$DB_HOST" ] && ! grep -q '^db_host' "$CONF"; then
  sed -i '/^\[options\]/a db_host = '"$DB_HOST" "$CONF"
fi
if [ -n "$DB_PORT" ]; then
  if ! grep -q '^db_port' "$CONF"; then
    sed -i '/^\[options\]/a db_port = '"$DB_PORT" "$CONF"
  fi
else
  if ! grep -q '^db_port' "$CONF"; then
    sed -i '/^\[options\]/a db_port = 10000' "$CONF"
  fi
fi
if [ -n "$DB_USER" ] && ! grep -q '^db_user' "$CONF"; then
  sed -i '/^\[options\]/a db_user = '"$DB_USER" "$CONF"
fi
if [ -n "$DB_PASSWORD" ] && ! grep -q '^db_password' "$CONF"; then
  sed -i '/^\[options\]/a db_password = '"$DB_PASSWORD" "$CONF"
fi
if [ -n "$DB_NAME" ] && ! grep -q '^db_name' "$CONF"; then
  sed -i '/^\[options\]/a db_name = '"$DB_NAME" "$CONF"
fi

# Memory limit for free-tier
if ! grep -q 'limit_memory_soft' "$CONF"; then
  sed -i '/^\[options\]/a limit_memory_soft = 2000000000' "$CONF"
fi

if [ -n "$ODOO_ADMIN_PASSWD" ]; then
  if ! grep -q 'admin_passwd' "$CONF"; then
    sed -i '/^\[options\]/a admin_passwd = '"$ODOO_ADMIN_PASSWD" "$CONF"
  fi
fi

# Ensure SSL is disabled (Render PostgreSQL doesn't require it)
sed -i '/^\[options\]/a db_sslmode = prefer' "$CONF"

echo "=== Generated odoo.conf ==="
cat "$CONF"
echo "==========================="

# Point Odoo to the modified config (can't write to /etc/odoo directly)
export ODOO_RC="$CONF"

# Wait for PostgreSQL to accept connections (Render free-tier DB can be slow to start)
if [ -n "$DB_HOST" ]; then
  DB_PORT_WAIT="${DB_PORT:-10000}"
  echo "Waiting for database at $DB_HOST:$DB_PORT_WAIT ..."
  ATTEMPTS=0
  MAX_ATTEMPTS=30
  while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if (echo > /dev/tcp/$DB_HOST/$DB_PORT_WAIT) 2>/dev/null; then
      echo "Database is ready!"
      break
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
    echo "  Attempt $ATTEMPTS/$MAX_ATTEMPTS — not ready yet, retrying in 5s..."
    sleep 5
  done
  if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "ERROR: Could not connect to database at $DB_HOST:$DB_PORT_WAIT after $((MAX_ATTEMPTS * 5))s"
    exit 1
  fi
fi

exec "$@"
