#!/bin/sh
set -eu

base_url="http://metabase:3000"
properties="$(curl --fail --silent --show-error "$base_url/api/session/properties")"
setup_token="$(printf '%s' "$properties" | sed -n 's/.*"setup-token":"\([^"]*\)".*/\1/p')"

if [ -n "$setup_token" ]; then
  echo "Completing initial Metabase setup..."
  curl --fail --silent --show-error -X POST "$base_url/api/setup" \
    -H 'Content-Type: application/json' \
    --data "{\"token\":\"$setup_token\",\"user\":{\"first_name\":\"Kingo\",\"last_name\":\"Student\",\"email\":\"$METABASE_ADMIN_EMAIL\",\"password\":\"$METABASE_ADMIN_PASSWORD\"},\"prefs\":{\"site_name\":\"SKKU Kingo Kit\",\"allow_tracking\":false},\"database\":null}" >/dev/null
fi

session="$(curl --fail --silent --show-error -X POST "$base_url/api/session" \
  -H 'Content-Type: application/json' \
  --data "{\"username\":\"$METABASE_ADMIN_EMAIL\",\"password\":\"$METABASE_ADMIN_PASSWORD\"}")"
session_id="$(printf '%s' "$session" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"

if [ -z "$session_id" ]; then
  echo "Could not authenticate to provision the Metabase warehouse connection." >&2
  exit 1
fi

databases="$(curl --fail --silent --show-error "$base_url/api/database" -H "X-Metabase-Session: $session_id")"
if printf '%s' "$databases" | grep -q '"name":"Kingo Warehouse"'; then
  echo "Metabase warehouse connection already exists."
  exit 0
fi

echo "Adding the Kingo Warehouse connection to Metabase..."
curl --fail --silent --show-error -X POST "$base_url/api/database" \
  -H 'Content-Type: application/json' \
  -H "X-Metabase-Session: $session_id" \
  --data "{\"engine\":\"postgres\",\"name\":\"Kingo Warehouse\",\"details\":{\"host\":\"postgres\",\"port\":5432,\"dbname\":\"warehouse\",\"user\":\"metabase\",\"password\":\"$METABASE_DB_PASSWORD\",\"ssl\":false},\"is_on_demand\":false,\"is_full_sync\":true,\"is_sample\":false}" >/dev/null
echo "Metabase provisioning complete."

