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

create_macos_documents_link() {
  local shared_dir="$1" documents_dir="$HOME/Documents" link_path
  link_path="$documents_dir/Kingokit"

  # Keep the canonical data outside Documents so Docker Desktop does not need
  # ongoing access to a macOS privacy-protected folder. The Finder-visible link
  # is only a discoverability aid and must never replace a user-created item.
  if [[ -e "$link_path" || -L "$link_path" ]]; then
    if [[ -L "$link_path" && "$(readlink "$link_path")" == "$shared_dir" ]]; then
      return 0
    fi
    echo "Not creating $link_path because an item already exists there." >&2
    return 0
  fi
  if ! mkdir -p "$documents_dir" || ! ln -s "$shared_dir" "$link_path"; then
    echo "Could not add the Kingokit link to Documents; student files remain in $shared_dir." >&2
    return 0
  fi
  echo "Added a Finder link to student files: $link_path"
}

create_windows_documents_shortcut() {
  local shared_dir="$1" documents_windows documents_wsl shortcut_wsl target_windows

  if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    echo "Could not add a Windows Documents shortcut; student files remain in $shared_dir." >&2
    return 0
  fi

  documents_windows="$(powershell.exe -NoProfile -NonInteractive -Command '[Environment]::GetFolderPath("MyDocuments")' 2>/dev/null | tr -d '\r')"
  documents_wsl="$(wslpath -u "$documents_windows" 2>/dev/null || true)"
  if [[ -z "$documents_windows" || -z "$documents_wsl" ]]; then
    echo "Could not locate Windows Documents; student files remain in $shared_dir." >&2
    return 0
  fi

  shortcut_wsl="$documents_wsl/Kingokit.lnk"
  if [[ -e "$documents_wsl/Kingokit" || -L "$documents_wsl/Kingokit" || -e "$shortcut_wsl" || -L "$shortcut_wsl" ]]; then
    echo "Not creating the Windows Documents shortcut because a Kingokit item already exists there." >&2
    return 0
  fi

  target_windows="$(wslpath -w "$shared_dir" 2>/dev/null || true)"
  if [[ -z "$target_windows" ]] || ! powershell.exe -NoProfile -NonInteractive -Command \
    '$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($args[0]); $shortcut.TargetPath = $args[1]; $shortcut.WorkingDirectory = $args[1]; $shortcut.Save()' \
    "$documents_windows\\Kingokit.lnk" "$target_windows" >/dev/null 2>&1; then
    echo "Could not add the Kingokit shortcut to Windows Documents; student files remain in $shared_dir." >&2
    return 0
  fi
  echo "Added a Windows Documents shortcut to student files: $documents_windows\\Kingokit.lnk"
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
