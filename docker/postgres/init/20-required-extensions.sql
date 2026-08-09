-- Required platform extensions are kept in one idempotent reconciliation file.
-- Docker's PostgreSQL entrypoint runs it for fresh volumes; `./kingo up` also
-- applies it to existing student volumes before starting dependent apps.

\connect kingo
CREATE EXTENSION IF NOT EXISTS vector;

-- Metabase migrations create objects in public and therefore need their own
-- application database rather than only a schema in the shared kingo DB.
\connect postgres
SELECT 'CREATE DATABASE metabase OWNER metabase'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase')\gexec
ALTER DATABASE metabase OWNER TO metabase;

\connect metabase
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;

\connect warehouse
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
