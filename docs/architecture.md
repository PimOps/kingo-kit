# Architecture

```mermaid
flowchart LR
    Browser["Ubuntu GUI or host browser"] --> Jupyter["JupyterLab :8888"]
    Browser --> Langflow["Langflow :7860"]
    Browser --> N8N["n8n :5678"]
    Browser --> Metabase["Metabase :3000"]
    Browser --> CloudBeaver["CloudBeaver :8978"]

    Jupyter --> Warehouse[("PostgreSQL + pgvector\nwarehouse")]
    Langflow --> Warehouse
    N8N --> Warehouse
    Metabase --> Warehouse
    CloudBeaver --> Warehouse

    Jupyter --> Platform[("PostgreSQL + pgvector\nkingo app schemas")]
    Langflow --> Platform
    N8N --> Platform
    Metabase --> Platform

    AW["PostgreSQL AdventureWorks source\none-shot profile"] --> Loader["Idempotent sample loader"]
    Azure["Microsoft WWI DW Parquet"] --> Loader
    Loader --> Warehouse

    Ollama["Host-native Ollama Cloud"] --> Claude["Claude Code"]
    Claude --> Repo["Kingo Kit / student projects"]
```

Each application is defined in its own `apps/APP/compose.yaml`; the root `compose.yaml` includes them for whole-stack operation. All long-running services share the private, externally named `kingo-kit` Docker network, which lets independently managed Compose projects resolve PostgreSQL as `postgres`. Persistent volumes have fixed Kingo Kit names so switching between aggregate and per-app commands does not create fresh application state. Only explicitly mapped ports are reachable from the Ubuntu host. The default bind address is loopback.

The AdventureWorks source container is only started by the `samples` Compose profile. Its PostgreSQL-native contents are streamed with `pg_dump`/`psql` into the main pgvector warehouse, after which the source container is stopped. WWI Parquet files are discovered from the public Azure Blob listing and copied in Arrow batches. Dataset completion markers live in `warehouse.kingo_meta.sample_loads`.
