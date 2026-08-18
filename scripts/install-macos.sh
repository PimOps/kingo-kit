#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
source "$script_dir/lib/install-common.sh"
init_kingo_logging install-macos

start_stack=true
load_samples=true
usage() {
  cat <<'EOF'
Usage: ./scripts/install-macos.sh [options]

Install Kingo Kit for the current macOS account. Docker Desktop must already
be installed and running; Homebrew is not required.

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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer requires macOS." >&2
  exit 1
fi

source_dir="$(kingo_source_dir)"
install_dir="${KINGOKIT_INSTALL_DIR:-$HOME/Library/Application Support/Kingo Kit}"
shared_dir="${KINGOKIT_SHARED_DIR:-$HOME/Kingokit}"
bin_dir="${KINGOKIT_BIN_DIR:-$HOME/.local/bin}"
profile_file="${KINGOKIT_PROFILE_FILE:-$HOME/.zprofile}"

log "Installing Kingo Kit for macOS..."
install_user_payload "$source_dir" "$install_dir"
create_shared_folder "$shared_dir"
create_macos_documents_link "$shared_dir"
install_user_command "$install_dir" "$bin_dir" "$profile_file"

if [[ "$start_stack" == true ]]; then
  log "Checking Docker Desktop is running..."
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Docker Desktop is not running. Start it, then run: kingo up" >&2
    exit 1
  fi
  log "Running: kingo up"
  "$install_dir/kingo" up
  if [[ "$load_samples" == true ]]; then
    log "Final step: loading the example databases. The applications are already running."
    "$install_dir/kingo" samples
  fi
fi

print_install_summary "$install_dir" "$shared_dir" "$bin_dir/kingo"
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
  echo "Open a new Terminal window before using 'kingo'."
else
  echo "Run 'kingo urls' to see the application links."
fi
