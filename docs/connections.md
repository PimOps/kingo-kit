# Connecting the Kingo Kit tools

Docker services reach PostgreSQL at `kingo-postgres:5432`. Programs running directly on Ubuntu (or through forwarded host ports) use `localhost` and the `POSTGRES_PORT` value from `.env`, which defaults to `5432`.

Docker Desktop may otherwise display Compose containers with a numeric replica suffix such as `postgres-1`. Kingo Kit assigns explicit container names and matching network hostnames instead:

| Application | Container/network hostname |
|---|---|
| PostgreSQL | `kingo-postgres` |
| JupyterLab | `kingo-jupyter` |
| Jupyter MCP Server | `kingo-jupyter-mcp` |
| Langflow | `kingo-langflow` |
| n8n | `kingo-n8n` |
| Metabase | `kingo-metabase` |
| CloudBeaver | `kingo-cloudbeaver` |
| Qdrant | `kingo-qdrant` |
| AdventureWorks import source | `kingo-adventureworks-source` (temporary) |
| Sample loader | `kingo-sample-loader` (temporary) |

The names are Kingo-specific, so an unrelated container named `postgres`, `jupyter`, or `n8n` does not conflict. The old `postgres` and `qdrant` network aliases remain temporarily available for saved connections, but new configurations should use the `kingo-` names.

Use the `warehouse` database for analysis. Most application state belongs in the `kingo` database and the application's named schema. Metabase uses a dedicated `metabase` application database because its migrations require control of the `public` schema.

## CloudBeaver

Sign in with the web credentials shown by `./kingo credentials`, select **New connection → PostgreSQL**, and enter:

| Field | Value |
|---|---|
| Host | `kingo-postgres` |
| Port | `5432` |
| Database | `warehouse` |
| User | `kingouser` (or `STUDENT_DB_USER` from `.env`) |
| Password | `STUDENT_DB_PASSWORD` shown by `./kingo credentials` |

Enable **Show all databases** if you also want to inspect the platform database. CloudBeaver keeps this connection in its persistent workspace.

## Metabase

Kingo Kit completes Metabase's first-run setup and adds **Kingo Warehouse** automatically. On the first start, Metabase may need another minute to scan all table metadata after its page becomes available.

Metabase stores its own users, settings, questions, and dashboards in the dedicated `metabase` database. This is separate from its automatically configured `warehouse` analytics connection.

If the automatic step was interrupted, add a PostgreSQL database with host `kingo-postgres`, port `5432`, database `warehouse`, user `metabase`, and `METABASE_DB_PASSWORD` from `.env`.

## n8n

n8n stores its own state in `kingo.n8n`. To create a separate PostgreSQL credential for data workflows, use:

| Field | Value |
|---|---|
| Host | `kingo-postgres` |
| Database | `warehouse` |
| User | `n8n` |
| Password | `N8N_DB_PASSWORD` from `.env` |
| Port | `5432` |
| SSL | Disabled |

The role can read the sample warehouse. For exercises that write results, use the `shared` schema in `kingo`, or have the instructor grant a dedicated warehouse schema.

## Langflow and LangGraph

Langflow's internal database is already configured in `kingo.langflow`. Components that query the warehouse can use:

```text
postgresql://langflow:PASSWORD@kingo-postgres:5432/warehouse
```

Replace `PASSWORD` with `LANGFLOW_DB_PASSWORD` from `.env`.

The prepared LangGraph login uses `kingo.langgraph` for checkpoints/application tables:

```text
postgresql://langgraph:PASSWORD@kingo-postgres:5432/kingo?options=-csearch_path%3Dlanggraph
```

LangGraph is a Python library rather than a separate web application in this stack. Install it in a course project or notebook as required by the lesson; the database role and schema are already ready.

## JupyterLab

The notebook container receives standard `PGHOST`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD` variables plus a SQLAlchemy `DATABASE_URL`. A minimal query is:

```python
import os
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(os.environ["DATABASE_URL"])
df = pd.read_sql("select * from wwi.dimension_date limit 10", engine)
df
```

## Qdrant

Containers reach Qdrant's REST API at `http://kingo-qdrant:6333` and its gRPC API at `kingo-qdrant:6334`. Programs running on Ubuntu or through the SSH tunnels use `http://localhost:6333`. The web dashboard is available at <http://localhost:6333/dashboard>.

JupyterLab includes the official Python client and receives `QDRANT_URL` automatically:

```python
import os
from qdrant_client import QdrantClient

qdrant = QdrantClient(url=os.environ["QDRANT_URL"])
qdrant.get_collections()
```

Langflow and n8n also receive `QDRANT_URL=http://kingo-qdrant:6333`. Use that value when configuring their Qdrant components or credentials. The local classroom instance has no API key and remains bound to `127.0.0.1` unless an instructor explicitly changes `BIND_ADDRESS`.

Qdrant stores vectors supplied by a client. It does not create embeddings itself, download an embedding model, or run a local LLM.

## Schema map

| Database | Schema(s) | Purpose |
|---|---|---|
| `warehouse` | `wwi` | WideWorldImportersDW analytics sample |
| `warehouse` | `Sales`, `Person`, `Production`, `Purchasing`, `HumanResources` | AdventureWorks sample (quote these mixed-case names in SQL) |
| `kingo` | `n8n` | n8n application state |
| `kingo` | `langflow` | Langflow application state |
| `kingo` | `langgraph` | LangGraph checkpoints and course projects |
| `metabase` | `public` | Metabase application state and Liquibase migrations |
| `kingo` | `cloudbeaver` | Reserved for CloudBeaver exercises/state |
| `kingo` | `jupyter` | Jupyter-owned course objects |
| `kingo` | `shared` | Cross-tool classroom exercises |
