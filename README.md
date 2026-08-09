# Kingo Kit

Kingo Kit is the one-command data and AI lab for students at Sungkyunkwan University (SKKU) Graduate School of Business. It turns a fresh Ubuntu Server or Ubuntu Desktop installation into the same reproducible classroom environment.

The stack includes:

- PostgreSQL 17 with pgvector, configured as a learning/data-warehouse server
- JupyterLab with pandas, Polars, SQLAlchemy, psycopg, pgvector, DuckDB, and common data-science libraries
- Langflow for visual AI workflows
- n8n for workflow automation
- Metabase for business intelligence (pre-connected to the warehouse)
- CloudBeaver for browser-based SQL and database exploration
- AdventureWorks and WideWorldImportersDW sample data in PostgreSQL
- Host-native Ollama, ready to configure Claude Code with `ollama launch claude`

## Quick start on fresh Ubuntu

Ubuntu 22.04, 24.04, or 26.04 on x86-64 or ARM64 is recommended. Give the VM at least 4 CPU cores, 12 GB RAM, and 35 GB free disk; 16 GB RAM is more comfortable when every app runs simultaneously.

On a fresh Ubuntu VM running in VMware Fusion, install the guest tools first:

```bash
sudo apt update
sudo apt install open-vm-tools open-vm-tools-desktop
```

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/YOUR-ORGANIZATION/kingo-kit.git
cd kingo-kit
./scripts/bootstrap-ubuntu.sh
```

The installer uses Docker Engine on both Server and Desktop. Docker Desktop is unnecessary on Ubuntu for this stack and consumes additional resources. On Ubuntu Desktop, open the URLs in Firefox; on Ubuntu Server, use SSH port forwarding or set up VM port forwarding as described below.

The first run downloads several large images and both datasets. It can take 10–30 minutes depending on the connection. It is safe to rerun the installer.

After installation:

```bash
./kingo urls
./kingo status
ollama launch claude
```

`ollama launch claude` is interactive the first time: it helps the student sign in/select an Ollama Cloud model and configures Claude Code. Ollama runs on Ubuntu itself, not in Docker, so coding tools can work naturally with files in the cloned repository.

## Daily commands

```bash
./kingo up                 # start/update the lab
./kingo down               # stop it without deleting data
./kingo status             # container status and health
./kingo urls               # URLs and usernames
./kingo credentials        # local classroom credentials
./kingo logs n8n           # follow one service's logs
./kingo samples            # retry/finish sample-data loading
./kingo psql               # warehouse SQL prompt
```

`make up`, `make down`, `make status`, and similar aliases are also provided.

## Services

| Service | Default URL/port | First login |
|---|---:|---|
| JupyterLab | <http://localhost:8888> | Token from `./kingo urls` |
| Langflow | <http://localhost:7860> | Auto-login classroom instance |
| n8n | <http://localhost:5678> | Create the local owner on first visit |
| Metabase | <http://localhost:3000> | From `./kingo credentials` |
| CloudBeaver | <http://localhost:8978> | From `./kingo credentials` |
| PostgreSQL | `localhost:5432` | From `./kingo credentials` |

Start with `notebooks/00_kingo_kit_welcome.ipynb` in JupyterLab.

## Database design

There are two PostgreSQL databases:

- `warehouse` is the shared analytics database. WideWorldImportersDW is in schema `wwi`; AdventureWorks retains its case-sensitive schemas: `Sales`, `Person`, `Production`, `Purchasing`, and `HumanResources`. The `vector`, `postgis`, and `uuid-ossp` extensions are enabled.
- `kingo` stores application state. Each tool has a separate schema and login: `n8n`, `langflow`, `langgraph`, `metabase`, `cloudbeaver`, and `jupyter`. A `shared` schema is available for cross-tool experiments.

Every application role can read the warehouse. This makes a teaching flow straightforward: extract/orchestrate with n8n, explore or transform in Jupyter, build AI flows in Langflow/LangGraph, inspect SQL in CloudBeaver, and visualize the result in Metabase.

See [docs/connections.md](docs/connections.md) for exact connection settings and examples.

## Access from a Mac or Windows host

The safest VM setup keeps `BIND_ADDRESS=127.0.0.1` in `.env` and uses the hypervisor's port-forwarding feature for the ports listed above. Alternatively, SSH forwards all web apps without exposing them to the LAN:

```bash
ssh -L 8888:localhost:8888 \
    -L 7860:localhost:7860 \
    -L 5678:localhost:5678 \
    -L 3000:localhost:3000 \
    -L 8978:localhost:8978 \
    -L 5432:localhost:5432 student@UBUNTU_IP
```

For a trusted, firewalled classroom/bridged network, changing `BIND_ADDRESS=0.0.0.0` exposes the services on the Ubuntu machine's IP. Do not do this on a public network: these are local teaching services, not a hardened internet deployment.

## Installation options

```bash
./scripts/bootstrap-ubuntu.sh --skip-samples
./scripts/bootstrap-ubuntu.sh --skip-ollama
```

If samples were skipped or the download was interrupted, run `./kingo samples` later. The loader records completed datasets and will not duplicate them.

## Configuration and upgrades

The first run creates `.env` from `.env.example` and generates random local passwords. `.env` is ignored by Git. Instructors can change ports, bind address, timezone, image versions, or credentials before starting the stack.

To apply a Compose or image update:

```bash
./kingo up
```

To permanently remove all container data and start over:

```bash
./kingo reset --yes
```

This deletes databases, n8n workflows, Langflow state, and web-app settings. Files saved in the repository's `notebooks/` directory remain.

## Troubleshooting

- `permission denied` for Docker immediately after bootstrap: current versions of `./kingo` transparently activate an already-granted Docker group membership. If the account was not added, run `sudo usermod -aG docker "$USER"` once and then log out and back in or reboot Ubuntu.
- A service is `unhealthy`: inspect it with `./kingo logs SERVICE`, for example `./kingo logs metabase`.
- A port is already in use: edit that service's host port in `.env`, then run `./kingo up`.
- Sample loading failed: verify internet access, then run `./kingo samples`. AdventureWorks and WWI are independently checkpointed.
- Low memory: stop unused apps with `docker compose stop langflow metabase`, or give the VM more RAM.
- Metabase was manually initialized with different credentials before provisioning completed: sign in and add PostgreSQL using the settings in `docs/connections.md`, or reset the stack on a disposable fresh install.

## Data provenance

AdventureWorks comes from the multi-architecture PostgreSQL port maintained in [`chriseaton/docker-adventureworks`](https://github.com/chriseaton/docker-adventureworks), built from Microsoft's sample. WideWorldImportersDW is loaded from Microsoft's public Azure Synapse sample-data Parquet export. The original WWI project is a SQL Server sample; loading the published Parquet tables avoids adding an entire SQL Server instance to the student VM.

Kingo Kit is intended for local education and development, not production or public internet hosting.
