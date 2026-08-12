#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skip_samples=false
skip_ollama=false

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-ubuntu.sh [options]

Install Docker Engine, Ollama, and the complete Kingo Kit classroom stack.

Options:
  --skip-samples  Start the apps without downloading the sample databases
  --skip-ollama   Do not install Ollama on the Ubuntu host
  -h, --help      Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-samples) skip_samples=true ;;
    --skip-ollama) skip_ollama=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -r /etc/os-release ]]; then
  echo "This installer requires Ubuntu Linux." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This installer supports Ubuntu; detected ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi
if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal student account, not as root; it will use sudo when needed." >&2
  exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required. Install it or ask the image administrator to add your account to sudoers." >&2
  exit 1
fi

echo "[1/6] Installing base packages..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl git zstd


if ! docker compose version >/dev/null 2>&1; then
  echo "[2/6] Installing Docker Engine and the Compose plugin..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  architecture="$(dpkg --print-architecture)"
  codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  printf '%s\n' \
    'Types: deb' \
    'URIs: https://download.docker.com/linux/ubuntu' \
    "Suites: $codename" \
    'Components: stable' \
    "Architectures: $architecture" \
    'Signed-By: /etc/apt/keyrings/docker.asc' \
    | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "[2/6] Docker Compose is already available."
fi

# Docker may have been preinstalled while its systemd unit remained disabled.
# Enabling it here ensures restart policies are honored after every reboot.
sudo systemctl enable --now docker

install_user="$(id -un)"
# Always reconcile the account database. Checking only the current process's
# groups can incorrectly skip this after Docker or a desktop session changes.
sudo groupadd --force docker
sudo usermod -aG docker "$install_user"
if ! id -nG "$install_user" | tr ' ' '\n' | grep -qx docker; then
  echo "Could not add $install_user to the docker group." >&2
  exit 1
fi
echo "Confirmed $install_user is assigned to the docker group."

if [[ "$skip_ollama" == false ]]; then
  if command -v ollama >/dev/null 2>&1; then
    echo "[3/6] Ollama is already installed."
  else
    echo "[3/6] Installing Ollama on the Ubuntu host..."
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://ollama.com/install.sh -o "$installer"
    sh "$installer"
    rm -f "$installer"
    trap - EXIT
  fi
else
  echo "[3/6] Skipping Ollama."
fi

echo "[4/6] Generating local credentials..."
if [[ -f "$repo_dir/.kingokit-installed" ]]; then
  state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kingokit"
  mkdir -p "$state_dir"
  KINGOKIT_ENV_FILE="$state_dir/.env" "$repo_dir/scripts/generate-env.sh"
  env_file="$state_dir/.env"
else
  "$repo_dir/scripts/generate-env.sh"
  env_file="$repo_dir/.env"
fi
export KINGOKIT_ENV_FILE="$env_file"

echo "[5/6] Configuring the Ubuntu wallpaper and Firefox homepage..."
"$repo_dir/scripts/configure-ubuntu-experience.sh"

shared_dir="$HOME/Kingokit"
# shellcheck source=lib/install-common.sh
source "$repo_dir/scripts/lib/install-common.sh"
create_shared_folder "$shared_dir"
export KINGOKIT_SHARED_DIR="$shared_dir"

# A fresh docker-group membership is not active in this shell, so use sudo only
# when the normal account cannot yet access the daemon.
if docker info >/dev/null 2>&1; then
  docker_command=(docker)
  compose=(docker compose --project-directory "$repo_dir" --env-file "$env_file")
else
  docker_command=(sudo docker)
  compose=(sudo env "KINGOKIT_SHARED_DIR=$shared_dir" "KINGOKIT_ENV_FILE=$env_file" docker compose --project-directory "$repo_dir" --env-file "$env_file")
fi

echo "[6/6] Starting Kingo Kit..."
echo "Created the shared student folder: $shared_dir"
if ! "${docker_command[@]}" network inspect kingo-kit >/dev/null 2>&1; then
  "${docker_command[@]}" network create kingo-kit >/dev/null
fi
"${compose[@]}" up -d --build --wait --wait-timeout 180 postgres
"${compose[@]}" exec -T postgres \
  psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
  --file /docker-entrypoint-initdb.d/20-required-extensions.sql >/dev/null
"${compose[@]}" up -d --build
sample_load_failed=false
if [[ "$skip_samples" == false ]]; then
  echo "Loading AdventureWorks and WideWorldImportersDW. This can take several minutes..."
  if ! "${compose[@]}" --profile samples run --name kingo-sample-loader --rm --build sample-loader; then
    sample_load_failed=true
    echo "Sample loading did not finish, but the Kingo Kit apps are running." >&2
    echo "Retry later with: $repo_dir/kingo samples" >&2
  fi
  "${compose[@]}" --profile samples stop adventureworks-source >/dev/null
fi

echo
echo "Kingo Kit is running."
"$repo_dir/kingo" urls
echo
if [[ "$skip_ollama" == false ]]; then
  echo "To configure and launch Claude Code with Ollama Cloud: ollama launch claude"
fi
echo "Log out and back in once before using docker directly without sudo."
if [[ "$sample_load_failed" == true ]]; then
  echo "The apps are ready; only the optional sample-data import remains incomplete."
fi
