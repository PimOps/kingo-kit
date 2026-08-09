# Connecting the Kingo Kit tools

Docker services reach PostgreSQL at `postgres:5432`. Programs running directly on Ubuntu (or through forwarded host ports) use `localhost` and the `POSTGRES_PORT` value from `.env`, which defaults to `5432`.

Use the `warehouse` database for analysis. Application state belongs in the `kingo` database and the application's named schema.

## CloudBeaver

Sign in with the web credentials shown by `./kingo credentials`, select **New connection → PostgreSQL**, and enter:

| Field | Value |
|---|---|
| Host | `postgres` |
| Port | `5432` |
| Database | `warehouse` |
| User | `student` |
| Password | `STUDENT_DB_PASSWORD` shown by `./kingo credentials` |

Enable **Show all databases** if you also want to inspect the platform database. CloudBeaver keeps this connection in its persistent workspace.

## Metabase

Kingo Kit completes Metabase's first-run setup and adds **Kingo Warehouse** automatically. On the first start, Metabase may need another minute to scan all table metadata after its page becomes available.

If the automatic step was interrupted, add a PostgreSQL database with host `postgres`, port `5432`, database `warehouse`, user `metabase`, and `METABASE_DB_PASSWORD` from `.env`.

## n8n

n8n stores its own state in `kingo.n8n`. To create a separate PostgreSQL credential for data workflows, use:

| Field | Value |
|---|---|
| Host | `postgres` |
| Database | `warehouse` |
| User | `n8n` |
| Password | `N8N_DB_PASSWORD` from `.env` |
| Port | `5432` |
| SSL | Disabled |

The role can read the sample warehouse. For exercises that write results, use the `shared` schema in `kingo`, or have the instructor grant a dedicated warehouse schema.

## Langflow and LangGraph

Langflow's internal database is already configured in `kingo.langflow`. Components that query the warehouse can use:

```text
postgresql://langflow:PASSWORD@postgres:5432/warehouse
```

Replace `PASSWORD` with `LANGFLOW_DB_PASSWORD` from `.env`.

The prepared LangGraph login uses `kingo.langgraph` for checkpoints/application tables:

```text
postgresql://langgraph:PASSWORD@postgres:5432/kingo?options=-csearch_path%3Dlanggraph
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

## Schema map

| Database | Schema(s) | Purpose |
|---|---|---|
| `warehouse` | `wwi` | WideWorldImportersDW analytics sample |
| `warehouse` | `Sales`, `Person`, `Production`, `Purchasing`, `HumanResources` | AdventureWorks sample (quote these mixed-case names in SQL) |
| `kingo` | `n8n` | n8n application state |
| `kingo` | `langflow` | Langflow application state |
| `kingo` | `langgraph` | LangGraph checkpoints and course projects |
| `kingo` | `metabase` | Metabase application state |
| `kingo` | `cloudbeaver` | Reserved for CloudBeaver exercises/state |
| `kingo` | `jupyter` | Jupyter-owned course objects |
| `kingo` | `shared` | Cross-tool classroom exercises |
