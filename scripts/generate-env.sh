#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_dir/.env"

if [[ -f "$env_file" ]]; then
  echo "Using existing $env_file"
  exit 0
fi

cp "$repo_dir/.env.example" "$env_file"

random_secret() {
  # Hex is URL-, YAML-, SQL-, and shell-safe, which matters because these values
  # are passed through all four layers.
  openssl rand -hex "$1"
}

replace_value() {
  local key="$1" value="$2"
  sed -i.bak "s|^${key}=.*|${key}=${value}|" "$env_file"
}

replace_value POSTGRES_PASSWORD "$(random_secret 18)"
replace_value N8N_DB_PASSWORD "$(random_secret 18)"
replace_value LANGFLOW_DB_PASSWORD "$(random_secret 18)"
replace_value LANGGRAPH_DB_PASSWORD "$(random_secret 18)"
replace_value METABASE_DB_PASSWORD "$(random_secret 18)"
replace_value CLOUDBEAVER_DB_PASSWORD "$(random_secret 18)"
replace_value JUPYTER_DB_PASSWORD "$(random_secret 18)"
replace_value STUDENT_DB_PASSWORD "$(random_secret 18)"
replace_value JUPYTER_TOKEN "$(random_secret 20)"
replace_value LANGFLOW_SECRET_KEY "$(random_secret 24)"
replace_value N8N_ENCRYPTION_KEY "$(random_secret 24)"
replace_value METABASE_ADMIN_PASSWORD "$(random_secret 18)"
replace_value CLOUDBEAVER_ADMIN_PASSWORD "$(random_secret 18)"
rm -f "$env_file.bak"
chmod 600 "$env_file"
echo "Created $env_file with random local credentials."

