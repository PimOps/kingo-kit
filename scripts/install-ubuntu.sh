#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "$script_dir/lib/install-common.sh"
init_kingo_logging install-ubuntu

usage() {
  cat <<'EOF'
Usage: ./scripts/install-ubuntu.sh [options]

Install Docker Engine, the host-native Ollama launcher, and Kingo Kit for the
current Ubuntu account.

Options:
  --skip-samples  Start the apps without downloading the sample databases
  --skip-ollama   Do not install Ollama on the Ubuntu host
  -h, --help      Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-samples|--skip-ollama) ;;
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
if [[ "$EUID" -eq 0 ]]; then
  echo "Run this installer as the normal student account, not as root." >&2
  exit 1
fi

source_dir="$(kingo_source_dir)"
install_dir="${KINGOKIT_INSTALL_DIR:-/opt/kingokit}"
shared_dir="${KINGOKIT_SHARED_DIR:-$HOME/Kingokit}"

log "Installing Kingo Kit application files in $install_dir..."
install_system_payload "$source_dir" "$install_dir"
create_shared_folder "$shared_dir"
sudo ln -sfn "$install_dir/kingo" /usr/local/bin/kingo

# Run the full Ubuntu provisioning from the installed, system-owned copy.
log "Running bootstrap-ubuntu.sh..."
"$install_dir/scripts/bootstrap-ubuntu.sh" "$@"

print_install_summary "$install_dir" "$shared_dir" /usr/local/bin/kingo
echo "Run 'kingo urls' to see the application links."
