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
sudo apt-get install -y ca-certificates curl git jq openssl zstd

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
  sudo systemctl enable --now docker
else
  echo "[2/6] Docker Compose is already available."
fi

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
"$repo_dir/scripts/generate-env.sh"

echo "[5/6] Configuring the Ubuntu wallpaper and Firefox homepage..."
"$repo_dir/scripts/configure-ubuntu-experience.sh"

# A fresh docker-group membership is not active in this shell, so use sudo only
# when the normal account cannot yet access the daemon.
if docker info >/dev/null 2>&1; then
  compose=(docker compose --project-directory "$repo_dir")
else
  compose=(sudo docker compose --project-directory "$repo_dir")
fi

echo "[6/6] Starting Kingo Kit..."
"${compose[@]}" up -d postgres
if [[ "$skip_samples" == false ]]; then
  echo "Loading AdventureWorks and WideWorldImportersDW. This can take several minutes..."
  "${compose[@]}" --profile samples run --rm --build sample-loader
  "${compose[@]}" --profile samples stop adventureworks-source >/dev/null
fi
"${compose[@]}" up -d --build

echo
echo "Kingo Kit is running."
"$repo_dir/kingo" urls
echo
if [[ "$skip_ollama" == false ]]; then
  echo "To configure and launch Claude Code with Ollama Cloud: ollama launch claude"
fi
echo "Log out and back in once before using docker directly without sudo."
