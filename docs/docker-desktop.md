# Running Kingo Kit with Docker Desktop

Kingo Kit can run directly on a macOS or Windows laptop. Students do not need to install or manage a separate Ubuntu virtual machine. Docker Desktop still uses a lightweight Linux backend internally, but Docker manages that backend automatically.

The Dockerized application stack is portable. The Ubuntu bootstrap script is not: it installs Linux packages and configures Docker Engine, Unix groups, GNOME wallpaper, and Firefox system policy. Mac and Windows users should install Docker Desktop themselves and start only the Compose stack.

The macOS and Windows/WSL Kingo Kit installers intentionally install no additional host-native applications. Tools that require broad host shell, Git, credential, or project access are omitted unless they can be provided safely and usefully as a containerized service.

## Compatibility overview

| Component | macOS | Windows |
|---|---|---|
| Docker Compose services | Supported | Supported with Linux containers |
| Intel/AMD64 hosts | Supported | Supported |
| Apple Silicon/ARM64 | Supported natively | Not applicable |
| Named persistent volumes | Supported | Supported |
| AdventureWorks and WWI import | Supported | Supported |
| Browser access through `localhost` | Supported | Supported |
| Jupyter MCP for local AI assistants | Supported | Supported |
| `./kingo` Bash launcher | Supported | Supported through WSL 2 or Git Bash |
| Native PowerShell launcher | Not applicable | Not implemented yet |
| Ubuntu wallpaper and Firefox policy | Not applicable | Not applicable |

The published images used by Kingo Kit provide Linux `amd64` and `arm64` variants, including PostgreSQL/pgvector, JupyterLab, Langflow, n8n, Metabase, CloudBeaver, Qdrant, and AdventureWorks.

## No Homebrew requirement

Homebrew is not required. Kingo Kit does not need `jq`: container health output is formatted by the Docker CLI itself, and Kingo Kit installs its complete Firefox policy without a separate JSON processor. It does not need `openssl` either: credential generation reads secure random bytes from `/dev/urandom` and converts them to shell-safe hexadecimal text with the standard `od` utility.

macOS supplies the utilities needed by the Bash launcher. Students should not install Homebrew solely for Kingo Kit.

## macOS setup

1. Install and start [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/). Choose the installer matching Apple silicon or Intel.
2. Install Git using the method already used by the student or instructor. Apple's Command Line Tools provide Git if it is not already present.
3. Clone and install Kingo Kit:

```bash
git clone https://github.com/PimOps/kingo-kit.git
cd kingo-kit
./scripts/install-macos.sh
```

Open the application links shown by:

```bash
kingo urls
```

The installer creates `~/Kingokit` and installs the application separately in `~/Library/Application Support/Kingo Kit`. It also creates a `Kingokit` link in the user's Documents folder, making the student files easy to find in Finder. The link points to `~/Kingokit`; files are not duplicated or moved. Keeping the real folder outside Documents avoids requiring Docker Desktop to continuously access a macOS privacy-protected folder. If an item named `Kingokit` already exists in Documents, the installer leaves it untouched.

The shared folder is mounted into JupyterLab, Langflow, and n8n, so files saved by those containers are available directly in Finder.

Do not run `scripts/bootstrap-ubuntu.sh` or `scripts/install-ubuntu.sh` on macOS.

## Windows setup: recommended WSL 2 workflow

Install Docker Desktop using its WSL 2 backend and enable integration for the student's WSL distribution under **Docker Desktop > Settings > Resources > WSL Integration**. Docker recommends keeping development repositories inside the WSL filesystem for better performance.

Open WSL and run:

```bash
git clone https://github.com/PimOps/kingo-kit.git
cd kingo-kit
./scripts/install-wsl.sh
```

The applications open in the normal Windows browser through `localhost`.

The student folder is stored in the WSL home directory at `~/Kingokit`. The installer adds a `Kingokit` shortcut to the user's actual Windows Documents folder, so students can open it directly from Windows Explorer. The shortcut points into WSL; files are not duplicated or moved. Keeping the real folder in WSL avoids the filesystem-performance and Linux-permission limitations of storing container workloads under `/mnt/c`.

The folder is also reachable directly from Windows Explorer under `\\wsl$\DISTRIBUTION_NAME\home\USERNAME\Kingokit`. If an item named `Kingokit` already exists in Windows Documents, the installer leaves it untouched.

See Docker's [WSL development guide](https://docs.docker.com/desktop/features/wsl/use-wsl/) for editor and filesystem recommendations.

## Windows setup without WSL

Docker Desktop can run the Compose services using Linux containers, but Kingo Kit does not yet provide a native PowerShell launcher or credential generator. Git Bash may run the existing scripts, but this path is not currently considered a first-class classroom workflow.

To make native Windows fully supported, Kingo Kit should add:

- `kingo.ps1` with equivalents for `up`, `down`, `status`, `health`, `urls`, `import`, and per-app commands;
- a PowerShell credential generator using .NET's cryptographic random-number generator;
- a Windows setup script that verifies Docker Desktop and Linux-container mode;
- automated parity checks between the Bash and PowerShell launchers.

Until those additions are complete, WSL 2 is the recommended Windows workflow.

## Resources

The complete stack is substantial. Allocate at least 8 GB of memory to Docker Desktop; 12–16 GB is more comfortable when every application runs simultaneously. Keep at least 40 GB of free disk space for images, persistent volumes, and sample data.

Students with less memory can run only selected applications:

```bash
./kingo app postgres up
./kingo app qdrant up
./kingo app jupyter up
```

Stop an unused application without deleting its volume:

```bash
./kingo app langflow down
```

At the end of the semester, `kingo uninstall` removes the complete Kingo Kit Docker stack and installed application files while retaining `~/Kingokit`. Docker Desktop itself is deliberately left installed.

## Networking and security

All host ports bind to `127.0.0.1` by default, so the applications are available to the student's browser without being exposed to the surrounding network. JupyterLab intentionally requires no token or password. Do not change `BIND_ADDRESS` to `0.0.0.0` on an untrusted network.

Qdrant is intentionally unauthenticated for local classroom use. Its loopback binding is therefore important. Docker services communicate through the private `kingo-kit` network using stable Kingo-specific names such as `kingo-postgres` and `kingo-qdrant`.

## Platform-specific features

The following Ubuntu experience features are intentionally skipped on Docker Desktop hosts:

- SKKU Kingo wallpaper installation;
- Firefox system homepage policy;
- Ubuntu Docker group management;
- systemd service configuration.

The AskKingo portal remains available directly at [www.askkingo.ai](https://www.askkingo.ai).
