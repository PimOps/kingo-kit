#!/usr/bin/env bash
set -Eeuo pipefail

source_dir="/opt/kingo/examples"
work_dir="/home/jovyan/work"
legacy_example_dir="$work_dir/examples"
example_dir="$work_dir/jupyter_examples"

# Migrate the original folder name once, but never merge or overwrite folders
# if a student already created the new destination independently.
if [[ -d "$legacy_example_dir" && ! -e "$example_dir" ]]; then
  mv -- "$legacy_example_dir" "$example_dir"
fi

mkdir -p "$example_dir"

# Seed newly added course examples into the student's persistent, writable
# Kingokit folder. Never overwrite a notebook the student may have edited.
if [[ -d "$source_dir" ]]; then
  shopt -s dotglob nullglob
  for source_path in "$source_dir"/*; do
    target_path="$example_dir/$(basename "$source_path")"
    if [[ ! -e "$target_path" ]]; then
      cp -a "$source_path" "$target_path"
    fi
  done
fi

exec start-notebook.py "$@"
