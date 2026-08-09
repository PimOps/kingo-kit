#!/usr/bin/env bash
set -Eeuo pipefail

required=(N8N_DB_PASSWORD LANGFLOW_DB_PASSWORD LANGGRAPH_DB_PASSWORD METABASE_DB_PASSWORD CLOUDBEAVER_DB_PASSWORD JUPYTER_DB_PASSWORD STUDENT_DB_PASSWORD)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required database password: ${name}" >&2
    exit 1
  fi
done

sql_quote() { printf "%s" "$1" | sed "s/'/''/g"; }

create_role() {
  local role="$1" password
  password="$(sql_quote "$2")"
  psql --username "$POSTGRES_USER" --dbname postgres --set ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${role}') THEN
    CREATE ROLE ${role} LOGIN PASSWORD '${password}';
  ELSE
    ALTER ROLE ${role} WITH LOGIN PASSWORD '${password}';
  END IF;
END
\$\$;
SQL
}

create_role n8n "$N8N_DB_PASSWORD"
create_role langflow "$LANGFLOW_DB_PASSWORD"
create_role langgraph "$LANGGRAPH_DB_PASSWORD"
create_role metabase "$METABASE_DB_PASSWORD"
create_role cloudbeaver "$CLOUDBEAVER_DB_PASSWORD"
create_role jupyter "$JUPYTER_DB_PASSWORD"
create_role student "$STUDENT_DB_PASSWORD"

psql --username "$POSTGRES_USER" --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE DATABASE warehouse OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'warehouse')\gexec
SQL

psql --username "$POSTGRES_USER" --dbname kingo --set ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA IF NOT EXISTS n8n AUTHORIZATION n8n;
CREATE SCHEMA IF NOT EXISTS langflow AUTHORIZATION langflow;
CREATE SCHEMA IF NOT EXISTS langgraph AUTHORIZATION langgraph;
CREATE SCHEMA IF NOT EXISTS metabase AUTHORIZATION metabase;
CREATE SCHEMA IF NOT EXISTS cloudbeaver AUTHORIZATION cloudbeaver;
CREATE SCHEMA IF NOT EXISTS jupyter AUTHORIZATION jupyter;
CREATE SCHEMA IF NOT EXISTS shared AUTHORIZATION postgres;

ALTER ROLE n8n IN DATABASE kingo SET search_path = n8n;
ALTER ROLE langflow IN DATABASE kingo SET search_path = langflow;
ALTER ROLE langgraph IN DATABASE kingo SET search_path = langgraph, shared, public;
ALTER ROLE metabase IN DATABASE kingo SET search_path = metabase;
ALTER ROLE cloudbeaver IN DATABASE kingo SET search_path = cloudbeaver;
ALTER ROLE jupyter IN DATABASE kingo SET search_path = jupyter, shared, public;

GRANT CONNECT ON DATABASE kingo TO n8n, langflow, langgraph, metabase, cloudbeaver, jupyter, student;
GRANT USAGE ON SCHEMA shared, public TO langgraph, jupyter, student;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA shared TO langgraph, jupyter, student;
ALTER DEFAULT PRIVILEGES IN SCHEMA shared GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO langgraph, jupyter, student;
ALTER DEFAULT PRIVILEGES IN SCHEMA shared GRANT USAGE, SELECT ON SEQUENCES TO langgraph, jupyter, student;
SQL

psql --username "$POSTGRES_USER" --dbname warehouse --set ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS wwi AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS kingo_meta AUTHORIZATION postgres;
CREATE TABLE IF NOT EXISTS kingo_meta.sample_loads (
  dataset text PRIMARY KEY,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  details jsonb NOT NULL DEFAULT '{}'::jsonb
);

GRANT CONNECT ON DATABASE warehouse TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student;
GRANT USAGE ON SCHEMA public, wwi TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student;
GRANT SELECT ON ALL TABLES IN SCHEMA public, wwi TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student;
ALTER DEFAULT PRIVILEGES IN SCHEMA wwi GRANT SELECT ON TABLES TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student;
SQL
