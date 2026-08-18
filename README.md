# Kingo Kit

Kingo Kit is the one-command data and AI lab for students at Sungkyunkwan University (SKKU) Graduate School of Business. It turns a fresh Ubuntu Server or Ubuntu Desktop installation into the same reproducible classroom environment.

The stack includes:

- PostgreSQL 17 with pgvector, configured as a learning/data-warehouse server
- Qdrant 1.19.0 for dedicated vector search and retrieval exercises
- JupyterLab with pandas, Polars, SQLAlchemy, psycopg, pgvector, DuckDB, and common data-science libraries
- Jupyter MCP Server for connecting local AI assistants to notebooks and kernels
- Langflow for visual AI workflows
- n8n for workflow automation
- Metabase for business intelligence (pre-connected to the warehouse)
- CloudBeaver for browser-based SQL and database exploration
- AdventureWorks and WideWorldImportersDW sample data, loadable on demand into PostgreSQL
- On Ubuntu only: host-native Ollama, ready to configure Claude Code with `ollama launch claude`
- Kingo Kit's SKKU-green hanok wallpaper on Ubuntu Desktop
- Firefox homepage configured as <https://www.askkingo.ai>

## Host installers

Clone the repository, then run the installer for the student's host:

```bash
# Ubuntu Server or Desktop
./scripts/install-ubuntu.sh

# macOS with Docker Desktop already installed
./scripts/install-macos.sh

# Windows, from WSL 2 with Docker Desktop integration enabled
./scripts/install-wsl.sh
```

All three installers provide the same separation between the application and student work:

| Purpose | Ubuntu | macOS | Windows WSL |
|---|---|---|---|
| Student files | `~/Kingokit` | `~/Kingokit` | `~/Kingokit` |
| Easy-to-find access | Home folder | `Documents/Kingokit` Finder link | `Kingokit` shortcut in Windows Documents |
| Application files | `/opt/kingokit` | `~/Library/Application Support/Kingo Kit` | `~/.local/share/kingokit` |
| Private configuration | `~/.config/kingokit` | `~/.config/kingokit` | `~/.config/kingokit` |
| Terminal command | `/usr/local/bin/kingo` | `~/.local/bin/kingo` | `~/.local/bin/kingo` |

The macOS and WSL installers do not install Docker Desktop themselves. They verify that it is running and explain what is missing. They do not install or configure host-native applications; Ollama integration is available only through the Ubuntu installer. Homebrew is not required. Use `--no-start` to install without starting containers. Sample data is not loaded by the installers; run `kingo import wwi` or `kingo import adventureworks` afterward when needed.

## Quick start on fresh Ubuntu

Ubuntu 22.04, 24.04, or 26.04 on x86-64 or ARM64 is recommended. Give the VM at least 4 CPU cores, 8 GB RAM, and 40 GB free disk; 16 GB RAM is more comfortable when every app runs simultaneously.

On a fresh Ubuntu VM running in VMware Fusion, install the guest tools first:

```bash
sudo apt update
sudo apt install open-vm-tools open-vm-tools-desktop
```

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/PimOps/kingo-kit.git
cd kingo-kit
./scripts/install-ubuntu.sh
```

The installer uses Docker Engine on both Server and Desktop. Docker Desktop is unnecessary on Ubuntu for this stack and consumes additional resources. On Ubuntu Desktop, open the URLs in Firefox; on Ubuntu Server, use SSH port forwarding or set up VM port forwarding as described below.

For the recommended macOS development workflow—including VMware Fusion networking, SSH keys, connection aliases, app tunnels, remote editing, and troubleshooting—see [docs/development.md](docs/development.md).

Students who prefer Docker Desktop on macOS or Windows can run the same application stack without a separate Ubuntu VM. See [docs/docker-desktop.md](docs/docker-desktop.md) for compatibility, installation, and platform differences.

On Ubuntu Desktop, the installer copies the Kingo Kit wallpaper to `/usr/local/share/backgrounds` and applies it to the student account for light and dark modes. Ubuntu Server safely skips the GNOME setting. Firefox receives an unlocked system policy that makes [www.askkingo.ai](https://www.askkingo.ai) its homepage and startup page while still allowing a student to change it.

The AskKingo homepage is the students' launch portal for Kingo Kit. It can provide links to the containerized applications, classroom instructions, troubleshooting guidance, and course updates. Because this information is hosted on the website, instructors can update it centrally without changing the repository or reinstalling anything on the students' Ubuntu machines.

The first run downloads several large images and both datasets. It can take 10–30 minutes depending on the connection. The installer starts PostgreSQL first, waits for the web applications to be running, and imports the example databases only as its final step. The applications remain available while that import runs. It is safe to rerun the installer.

After installation:

```bash
kingo urls
kingo status
ollama launch claude
```

On Ubuntu, `ollama launch claude` is interactive the first time: it helps the student sign in/select an Ollama Cloud model and configures Claude Code. Ollama runs on Ubuntu itself, not in Docker, so coding tools can work naturally with files in `~/Kingokit`. This component is omitted from the macOS and Windows/WSL installations.

## Windows setup with Docker Desktop already installed

The recommended Windows workflow uses Docker Desktop's WSL 2 backend:

1. Enable integration for the student's WSL distribution under **Docker Desktop > Settings > Resources > WSL Integration**.
2. Open the WSL distribution's terminal (not PowerShell or Command Prompt) and run:

   ```bash
   git clone https://github.com/PimOps/kingo-kit.git
   cd kingo-kit
   ./scripts/install-wsl.sh
   ```
3. Open the application links:

   ```bash
   kingo urls
   ```

The applications open in the normal Windows browser through `localhost`. The student folder lives at `~/Kingokit` inside WSL; the installer adds a `Kingokit` shortcut in the actual Windows Documents folder pointing into WSL, without duplicating or moving files.

Kingo Kit does not yet provide a native PowerShell launcher or credential generator, so running outside WSL (for example with Git Bash) is not a first-class supported path. See [docs/docker-desktop.md](docs/docker-desktop.md) for details.

## Daily commands

```bash
kingo up                 # start/update the lab
kingo down               # stop it without deleting data
kingo status             # container status and health
kingo health metabase    # health-check details and recent logs
kingo urls               # URLs and usernames
kingo credentials        # local classroom credentials
kingo mcp                # MCP endpoint, bearer token, and client example
kingo logs n8n           # follow one service's logs
kingo app jupyter up     # manage only one application
kingo app qdrant up      # start only Qdrant
kingo app metabase logs  # follow one application's logs
kingo docker ps          # Docker CLI through the group-access fallback
kingo import wwi         # load WideWorldImportersDW
kingo import adventureworks # load AdventureWorks
kingo psql               # warehouse SQL prompt
```

`make up`, `make down`, `make status`, and similar aliases are also provided.

## Modular Compose layout

Every application has its own folder and standalone Compose file:

| Folder | Contents |
|---|---|
| `apps/postgres/` | PostgreSQL, pgvector, PostGIS, schemas, and application users |
| `apps/jupyter/` | JupyterLab and its persistent home volume |
| `apps/jupyter-mcp/` | Authenticated Streamable HTTP bridge for local AI assistants |
| `apps/langflow/` | Langflow |
| `apps/n8n/` | n8n |
| `apps/metabase/` | Metabase and its automatic warehouse setup helper |
| `apps/cloudbeaver/` | CloudBeaver |
| `apps/qdrant/` | Qdrant vector database and persistent vector storage |
| `apps/sample-data/` | One-shot AdventureWorks and WWI import tooling |

The root `compose.yaml` includes these files to retain the simple `./kingo up` whole-lab workflow. All application files connect to the shared external `kingo-kit` Docker network, and their explicitly named volumes preserve compatibility with existing Kingo Kit installations. Use `./kingo app NAME ACTION` to operate one application without having to remember Compose paths or project options; supported actions are `up`, `down`, `restart`, `status`, and `logs`.

PostgreSQL is the common dependency. Start it before running another application independently:

```bash
./kingo app postgres up
./kingo app jupyter up
```

See [`apps/README.md`](apps/README.md) for direct Docker Compose commands intended for maintainers.

## Services

| Service | Default URL/port | First login |
|---|---:|---|
| JupyterLab | <http://localhost:8888> | No login required |
| Jupyter MCP | <http://localhost:4040/mcp> | Bearer token from `kingo mcp` |
| Langflow | <http://localhost:7860> | Auto-login classroom instance |
| n8n | <http://localhost:5678> | Create an account on first visit |
| Metabase | <http://localhost:3000> | From `./kingo credentials` |
| CloudBeaver | <http://localhost:8978> | From `./kingo credentials` |
| Qdrant dashboard | <http://localhost:6333/dashboard> | Local classroom instance; no login |
| PostgreSQL | `localhost:5432` | From `./kingo credentials` |

Fresh installations use the same classroom credentials wherever an application
requires a conventional login: username `kingouser`, email `user@kingo.local`,
and password `Unique_Origin_Unique_Future1`. Run `kingo credentials` to see
which form each service uses. Internal service-to-service database passwords
and the Jupyter MCP bearer token remain randomly generated.

Start with `jupyter_examples/00_kingo_kit_welcome.ipynb` in JupyterLab. It is a writable copy stored in `~/Kingokit/jupyter_examples` on the host.

Notebook shell commands run from the directory containing the open notebook. For a separate `uv` project, create and enter a folder under the writable workspace first:

```python
from pathlib import Path
Path("/home/jovyan/work/my-project").mkdir(exist_ok=True)
%cd /home/jovyan/work/my-project
!uv init
```

Local AI assistants that support MCP can control Jupyter notebooks and kernels through the authenticated Streamable HTTP endpoint. Run `kingo mcp` for the endpoint and bearer token, and see [docs/jupyter-mcp.md](docs/jupyter-mcp.md) for client examples and security guidance.

## Shared student files

The installer and launcher create `~/Kingokit`. Files placed there remain ordinary host files, so students can open and save them with Finder, Windows Explorer, or Ubuntu's Files application while also using them inside the containers. For easier discovery, the macOS installer adds a `Kingokit` link in Documents and the WSL installer adds a `Kingokit` shortcut to the actual Windows Documents folder. These links point to the canonical `~/Kingokit` folder; they do not duplicate or move student files. The installer leaves an existing item with the same name untouched.

Keeping the canonical folder in the user's home directory avoids requiring Docker Desktop to continuously access macOS's privacy-protected Documents folder and avoids storing container workloads on the slower Windows-mounted filesystem under `/mnt/c`. Existing installations using the former `~/kingokit` name are renamed automatically without deleting their contents:

| Application | Path inside the container |
|---|---|
| JupyterLab | `/home/jovyan/work` (the file browser opens directly here) |
| Langflow | `/app/kingokit` |
| n8n | `/home/node/kingokit` |

The shared folder survives `kingo down`, `kingo reset --yes`, and application upgrades because it is not a Docker volume or part of the installed application directory. At startup, missing example notebooks are copied into `~/Kingokit/jupyter_examples`. Existing copies are never overwritten, so student edits are retained. An existing `~/Kingokit/examples` folder is renamed automatically when the new name is not already present.

## Database design

There are three PostgreSQL databases:

- `warehouse` is the shared analytics database. WideWorldImportersDW is in schema `wwi`; AdventureWorks retains its case-sensitive schemas: `Sales`, `Person`, `Production`, `Purchasing`, and `HumanResources`. The `vector`, `postgis`, and `uuid-ossp` extensions are enabled.
- `kingo` stores shared application state. Each compatible tool has a separate schema and login: `n8n`, `langflow`, `langgraph`, `cloudbeaver`, and `jupyter`. A `shared` schema is available for cross-tool experiments.
- `metabase` is Metabase's dedicated application database. Metabase requires control of its application database's `public` schema for Liquibase migrations; it uses a separate connection to read the `warehouse` database.

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
    -L 6333:localhost:6333 \
    -L 6334:localhost:6334 \
    -L 4040:localhost:4040 \
    -L 5432:localhost:5432 student@UBUNTU_IP
```

For a trusted, firewalled classroom/bridged network, changing `BIND_ADDRESS=0.0.0.0` exposes the services on the Ubuntu machine's IP. Do not do this on a public network: these are local teaching services, not a hardened internet deployment. JupyterLab deliberately has no login, so keeping it on loopback or behind an SSH tunnel is especially important.

Qdrant is intentionally unauthenticated for local classroom use and is bound to loopback by default. It stores and searches vectors but does not generate embeddings, run an LLM, or download any model.

## Installation options

```bash
./scripts/install-ubuntu.sh --skip-ollama
```

Sample data is not loaded automatically. Run `kingo import wwi` or `kingo import adventureworks` after the install finishes; each dataset is independently checkpointed and safe to retry.

To reapply only the wallpaper and Firefox homepage configuration:

```bash
./scripts/configure-ubuntu-experience.sh
```

## Configuration and upgrades

The first run creates `~/.config/kingokit/.env` from `.env.example`. The classroom-facing accounts use the shared defaults above, while internal service passwords and tokens are generated randomly. Instructors can change ports, bind address, timezone, image versions, or credentials before starting the installed stack. When running directly from a development clone, `.env` remains in the repository and is ignored by Git.

Students can change the n8n, Metabase, and CloudBeaver passwords in each application's account settings. Langflow remains in auto-login mode by default; set `LANGFLOW_AUTO_LOGIN=false` and change its superuser values in `.env` to require a login. To change the classroom PostgreSQL login, edit `STUDENT_DB_USER` and `STUDENT_DB_PASSWORD` in `.env`, then run `kingo up`; Kingo Kit reconciles that role without deleting data. Environment values initialize fresh web-app volumes but intentionally do not overwrite accounts already changed through an application's UI.

Before dependent applications start, `./kingo up` idempotently reconciles PostgreSQL's required extensions (`vector`, `citext`, PostGIS, and `uuid-ossp`). This also upgrades existing student volumes safely when a newer application version introduces an extension requirement.

To apply a Compose or image update:

```bash
./kingo up
```

To factory-reset all application state and immediately start a clean stack:

```bash
kingo reset --yes
```

This deletes databases, n8n workflows, Langflow state, and web-app settings, but retains downloaded images and the Kingo Kit installation. Files saved in `~/Kingokit` remain. Sample databases are not loaded automatically after a reset; run `kingo import wwi` or `kingo import adventureworks` when they are needed.

## Uninstalling after the semester

Run the interactive uninstaller from any directory:

```bash
kingo uninstall
```

For a managed or non-interactive machine, confirmation can be supplied explicitly:

```bash
kingo uninstall --yes
```

During repeated installation testing, retain downloaded and locally built Docker
images while removing the containers, volumes, credentials, and installed files:

```bash
kingo uninstall --keep-images
```

The shorter `-keepimages` spelling is also accepted. Combine either form with
`--yes` for an unattended uninstall.

By default, uninstall removes all Kingo Kit containers, images, volumes, its Docker network, generated credentials, the terminal command, and the installed application files. With `--keep-images`, only the images are retained. It always retains the student's work in `~/Kingokit`. It does **not** uninstall Docker Desktop, Docker Engine, or WSL. On Ubuntu, it also retains the separately installed Ollama host application.

## Troubleshooting

- `permission denied` for direct Docker commands: run `./kingo doctor` to distinguish account membership, session membership, daemon status, and socket permissions. `./kingo docker ps` works through Kingo's group-access fallback. If the account is listed in the Docker group but the current session is not, `newgrp docker` activates it in the current terminal. If the account was not added, run `sudo usermod -aG docker "$USER"` once and reboot Ubuntu.
- A service is `unhealthy`: inspect its health-check history and recent logs with `./kingo health SERVICE`, for example `./kingo health metabase`.
- A port is already in use: edit that service's host port in `~/.config/kingokit/.env`, then run `kingo up`.
- Sample loading failed: verify internet access, then rerun `./kingo import wwi` or `./kingo import adventureworks`. AdventureWorks and WWI are independently checkpointed.
- Low memory: stop unused apps with `./kingo app langflow down` and `./kingo app metabase down`, or give the VM more RAM.
- Metabase was manually initialized with different credentials before provisioning completed: sign in and add PostgreSQL using the settings in `docs/connections.md`, or reset the stack on a disposable fresh install.

## Data provenance

AdventureWorks comes from the multi-architecture PostgreSQL port maintained in [`chriseaton/docker-adventureworks`](https://github.com/chriseaton/docker-adventureworks), built from Microsoft's sample. WideWorldImportersDW is loaded from Microsoft's public Fabric tutorial-data Parquet export. The original WWI project is a SQL Server sample; loading the published Parquet tables avoids adding an entire SQL Server instance to the student VM. Its source URL is configurable with `WWI_CONTAINER_URL` in `.env`.

Kingo Kit is intended for local education and development, not production or public internet hosting.
