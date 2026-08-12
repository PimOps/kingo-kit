#!/usr/bin/env bash

# Shared helpers for the host-specific installers. The calling script enables
# strict mode and supplies the destination paths.

kingo_source_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

stage_kingo_payload() {
  local source_dir="$1" stage_dir="$2"
  mkdir -p "$stage_dir"
  tar \
    --exclude='./.git' \
    --exclude='./.env' \
    --exclude='./kingokit' \
    --exclude='./Kingokit' \
    --exclude='./.DS_Store' \
    -C "$source_dir" -cf - . | tar -C "$stage_dir" -xf -
  touch "$stage_dir/.kingokit-installed"
}

install_user_payload() {
  local source_dir="$1" install_dir="$2" stage_root
  stage_root="$(mktemp -d)"
  stage_kingo_payload "$source_dir" "$stage_root/payload"
  mkdir -p "$install_dir"
  cp -R "$stage_root/payload/." "$install_dir/"
  chmod +x "$install_dir/kingo" "$install_dir/scripts/"*.sh
  rm -rf "$stage_root"
}

install_system_payload() {
  local source_dir="$1" install_dir="$2" stage_root
  stage_root="$(mktemp -d)"
  stage_kingo_payload "$source_dir" "$stage_root/payload"
  sudo install -d -m 0755 "$install_dir"
  sudo cp -R "$stage_root/payload/." "$install_dir/"
  sudo chown -R root:root "$install_dir"
  sudo chmod +x "$install_dir/kingo" "$install_dir/scripts/"*.sh
  rm -rf "$stage_root"
}

create_shared_folder() {
  local shared_dir="$1"
  local canonical_dir="$HOME/Kingokit" legacy_dir actual_canonical migration_dir
  legacy_dir="$(find "$HOME" -mindepth 1 -maxdepth 1 -type d -name kingokit -print -quit 2>/dev/null || true)"
  actual_canonical="$(find "$HOME" -mindepth 1 -maxdepth 1 -type d -name Kingokit -print -quit 2>/dev/null || true)"
  if [[ "$shared_dir" == "$canonical_dir" && -n "$legacy_dir" && -z "$actual_canonical" ]]; then
    migration_dir="$(mktemp -d "$HOME/.kingokit-migration.XXXXXX")"
    mv "$legacy_dir" "$migration_dir/Kingokit"
    if mv "$migration_dir/Kingokit" "$canonical_dir"; then
      rmdir "$migration_dir"
      echo "Renamed the existing student folder to $canonical_dir"
    else
      mv "$migration_dir/Kingokit" "$legacy_dir"
      rmdir "$migration_dir"
      echo "Could not rename $legacy_dir to $canonical_dir; existing files were restored." >&2
      return 1
    fi
  fi
  mkdir -p "$shared_dir"
  chmod a+rwx "$shared_dir"
}

install_user_command() {
  local install_dir="$1" bin_dir="$2" profile_file="$3"
  local path_line="export PATH=\"$bin_dir:\$PATH\""
  mkdir -p "$bin_dir"
  ln -sfn "$install_dir/kingo" "$bin_dir/kingo"
  if [[ ":$PATH:" != *":$bin_dir:"* ]] && ! grep -Fqx "$path_line" "$profile_file" 2>/dev/null; then
    printf '\n# Kingo Kit command\n%s\n' "$path_line" >>"$profile_file"
  fi
  export PATH="$bin_dir:$PATH"
}

print_install_summary() {
  local install_dir="$1" shared_dir="$2" command_path="$3"
  printf '\nKingo Kit installation complete.\n'
  printf 'Application files: %s\n' "$install_dir"
  printf 'Student files:     %s\n' "$shared_dir"
  printf 'Command:           %s\n' "$command_path"
}
