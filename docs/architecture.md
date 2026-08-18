# Architecture

```mermaid
flowchart LR
    Browser["Ubuntu GUI or host browser"] --> Jupyter["JupyterLab :8888"]
    Browser --> Langflow["Langflow :7860"]
    Browser --> N8N["n8n :5678"]
    Browser --> Metabase["Metabase :3000"]
    Browser --> CloudBeaver["CloudBeaver :8978"]
    Browser --> Qdrant["Qdrant dashboard/API :6333"]
    Assistant["Local AI assistant"] --> MCP["Jupyter MCP :4040/mcp"]
    MCP --> Jupyter

    Jupyter --> Warehouse[("PostgreSQL + pgvector\nwarehouse")]
    Langflow --> Warehouse
    N8N --> Warehouse
    Metabase --> Warehouse
    CloudBeaver --> Warehouse
    Jupyter --> Qdrant
    Langflow --> Qdrant
    N8N --> Qdrant

    Jupyter --> Platform[("PostgreSQL + pgvector\nkingo app schemas")]
    Langflow --> Platform
    N8N --> Platform
    Metabase --> MetabaseDB[("PostgreSQL\nmetabase app database")]

    AW["PostgreSQL AdventureWorks source\none-shot profile"] --> Loader["Idempotent sample loader"]
    Azure["Microsoft WWI DW Parquet"] --> Loader
    Loader --> Warehouse

    Ollama["Ubuntu Linux only: host-native Ollama Cloud"] --> Claude["Claude Code"]
    Claude --> Repo["Kingo Kit / student projects"]
```

Each application is defined in its own `apps/APP/compose.yaml`; the root `compose.yaml` includes them for whole-stack operation. All long-running services share the private, externally named `kingo-kit` Docker network. Containers and network aliases use a Kingo-specific name such as `kingo-postgres`, `kingo-jupyter`, and `kingo-qdrant`; these are the stable hostnames applications should use for internal connections. Persistent volumes have fixed Kingo Kit names so switching between aggregate and per-app commands does not create fresh application state. Only explicitly mapped ports are reachable from the Ubuntu host. The default bind address is loopback.

The Jupyter MCP Server is a containerized, bearer-token-protected Streamable HTTP bridge. Its host port is bound to loopback by default, and it reaches JupyterLab at the stable private hostname `kingo-jupyter`. Ollama and its Claude Code launcher are host-native Ubuntu Linux additions, not Compose services. They are omitted from the macOS and Windows/WSL installers.

The AdventureWorks source container is only started by the `samples` Compose profile. Its PostgreSQL-native contents are streamed with `pg_dump`/`psql` into the main pgvector warehouse, after which the source container is stopped. WWI Parquet files are discovered from the public Azure Blob listing and copied in Arrow batches. Dataset completion markers live in `warehouse.kingo_meta.sample_loads`.
