#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "$script_dir/lib/install-common.sh"

start_stack=true
load_samples=true
usage() {
  cat <<'EOF'
Usage: ./scripts/install-wsl.sh [options]

Install Kingo Kit in a WSL 2 distribution. Docker Desktop with WSL integration
must already be installed and running in Windows.

Options:
  --no-start      Install the command and files without starting containers
  --skip-samples  Start the apps without loading the sample databases
  -h, --help      Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-start) start_stack=false ;;
    --skip-samples) load_samples=false ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -r /proc/version ]] || ! grep -qi microsoft /proc/version; then
  echo "This installer requires Windows Subsystem for Linux (WSL 2)." >&2
  exit 1
fi

source_dir="$(kingo_source_dir)"
install_dir="${KINGOKIT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/kingokit}"
shared_dir="${KINGOKIT_SHARED_DIR:-$HOME/Kingokit}"
bin_dir="${KINGOKIT_BIN_DIR:-$HOME/.local/bin}"
profile_file="${KINGOKIT_PROFILE_FILE:-$HOME/.profile}"

echo "Installing Kingo Kit for Windows WSL..."
install_user_payload "$source_dir" "$install_dir"
create_shared_folder "$shared_dir"
install_user_command "$install_dir" "$bin_dir" "$profile_file"

if [[ "$start_stack" == true ]]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Docker Desktop's WSL integration is unavailable." >&2
    echo "Enable this distribution under Docker Desktop > Settings > Resources > WSL Integration, then run: kingo up" >&2
    exit 1
  fi
  "$install_dir/kingo" up
  if [[ "$load_samples" == true ]]; then
    "$install_dir/kingo" samples
  fi
fi

print_install_summary "$install_dir" "$shared_dir" "$bin_dir/kingo"
echo "Open a new WSL terminal, then run 'kingo urls'."
