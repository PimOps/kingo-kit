#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${KINGOKIT_ENV_FILE:-$repo_dir/.env}"

created=false
if [[ ! -f "$env_file" ]]; then
  mkdir -p "$(dirname "$env_file")"
  cp "$repo_dir/.env.example" "$env_file"
  created=true
fi

random_secret() {
  # Hex is URL-, YAML-, SQL-, and shell-safe, which matters because these values
  # are passed through all four layers. /dev/urandom and od are standard on
  # Ubuntu, macOS, and WSL, so no separate crypto package is needed.
  if [[ ! -r /dev/urandom ]] || ! command -v od >/dev/null 2>&1; then
    echo "Cannot generate credentials: /dev/urandom and the standard od utility are required." >&2
    return 1
  fi
  LC_ALL=C od -An -N "$1" -tx1 /dev/urandom | tr -d ' \n'
}

replace_value() {
  local key="$1" value="$2"
  sed -i.bak "s|^${key}=.*|${key}=${value}|" "$env_file"
}

ensure_secret() {
  local key="$1" bytes="$2" current
  current="$(sed -n "s/^${key}=//p" "$env_file" | tail -n 1)"
  if [[ -z "$current" ]]; then
    printf '%s=%s\n' "$key" "$(random_secret "$bytes")" >>"$env_file"
  elif [[ "$current" == CHANGE_ME_* ]]; then
    replace_value "$key" "$(random_secret "$bytes")"
  fi
}

ensure_default() {
  local key="$1" value="$2"
  if ! grep -q "^${key}=" "$env_file"; then
    printf '%s=%s\n' "$key" "$value" >>"$env_file"
  fi
}

ensure_secret POSTGRES_PASSWORD 18
ensure_secret N8N_DB_PASSWORD 18
ensure_secret LANGFLOW_DB_PASSWORD 18
ensure_secret LANGGRAPH_DB_PASSWORD 18
ensure_secret METABASE_DB_PASSWORD 18
ensure_secret CLOUDBEAVER_DB_PASSWORD 18
ensure_secret JUPYTER_DB_PASSWORD 18
ensure_secret JUPYTER_MCP_TOKEN 24
ensure_secret LANGFLOW_SECRET_KEY 24
ensure_secret N8N_ENCRYPTION_KEY 24
ensure_default STUDENT_DB_USER kingouser
ensure_default STUDENT_DB_PASSWORD change_me_later
ensure_default LANGFLOW_AUTO_LOGIN true
ensure_default LANGFLOW_SUPERUSER kingouser
ensure_default LANGFLOW_SUPERUSER_PASSWORD change_me_later
ensure_default METABASE_ADMIN_EMAIL user@kingo.local
ensure_default METABASE_ADMIN_PASSWORD change_me_later
ensure_default CLOUDBEAVER_ADMIN_USER kingouser
ensure_default CLOUDBEAVER_ADMIN_PASSWORD change_me_later
rm -f "$env_file.bak"
chmod 600 "$env_file"
if [[ "$created" == true ]]; then
  echo "Created $env_file with random local credentials."
else
  echo "Checked $env_file and added any missing Kingo Kit credentials."
fi
