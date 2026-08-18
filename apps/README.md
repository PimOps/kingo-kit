# Application Compose files

Each Kingo Kit application has an independent `compose.yaml`. Students should normally use the `./kingo` wrapper from the repository root because it creates the shared network, loads `.env`, and keeps a consistent Compose project name.

The launcher also exports `KINGOKIT_SHARED_DIR` for the bind mounts used by JupyterLab, Langflow, and n8n. Maintainers running Compose directly must export it first, for example `export KINGOKIT_SHARED_DIR="$HOME/Kingokit"`.

```bash
./kingo app postgres up
./kingo app jupyter up
./kingo app jupyter-mcp up
./kingo app jupyter status
./kingo app jupyter logs
./kingo app jupyter down
./kingo app qdrant up
```

Maintainers can invoke an application file directly from the repository root. Create the shared network once, use the root environment file, and retain the `kingo-kit` project name so the command manages the same containers and volumes as the aggregate stack:

```bash
docker network inspect kingo-kit >/dev/null 2>&1 || docker network create kingo-kit
docker compose \
  --project-name kingo-kit \
  --env-file .env \
  --file apps/jupyter/compose.yaml \
  up -d
```

PostgreSQL must be running before database-backed applications are started. The sample-data Compose file is a one-shot maintenance utility and is normally invoked with `./kingo samples`.
