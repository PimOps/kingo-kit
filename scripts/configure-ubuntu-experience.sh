#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_source="$repo_dir/images/kingo-kit-wallpaper.png"
wallpaper_dir="/usr/local/share/backgrounds"
wallpaper_target="$wallpaper_dir/kingo-kit-wallpaper.png"
firefox_policy_source="$repo_dir/config/firefox/policies.json"
firefox_policy_dir="/etc/firefox/policies"
firefox_policy_target="$firefox_policy_dir/policies.json"

if [[ ! -f "$wallpaper_source" ]]; then
  echo "Wallpaper asset is missing: $wallpaper_source" >&2
  exit 1
fi
if [[ ! -f "$firefox_policy_source" ]]; then
  echo "Firefox policy is missing: $firefox_policy_source" >&2
  exit 1
fi

echo "Installing the Kingo Kit wallpaper..."
sudo install -d -m 0755 "$wallpaper_dir"
sudo install -m 0644 "$wallpaper_source" "$wallpaper_target"

run_gsettings() {
  local user_bus="/run/user/$(id -u)/bus"
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gsettings "$@"
  elif [[ -S "$user_bus" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$user_bus" gsettings "$@"
  elif command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- gsettings "$@"
  else
    return 1
  fi
}

if command -v gsettings >/dev/null 2>&1; then
  available_schemas="$(gsettings list-schemas)"
  if [[ "$available_schemas" == *"org.gnome.desktop.background"* ]]; then
    wallpaper_uri="file://$wallpaper_target"
    run_gsettings set org.gnome.desktop.background picture-uri "$wallpaper_uri"
    run_gsettings set org.gnome.desktop.background picture-uri-dark "$wallpaper_uri"
    run_gsettings set org.gnome.desktop.background picture-options zoom
    echo "Applied the Kingo Kit wallpaper to this Ubuntu Desktop account."
  else
    echo "GNOME Desktop is not installed; the wallpaper setting was skipped."
  fi
else
  echo "This is an Ubuntu Server-style installation; the wallpaper setting was skipped."
fi

echo "Configuring the Firefox homepage..."
sudo install -d -m 0755 "$firefox_policy_dir"
if [[ -f "$firefox_policy_target" ]] && command -v jq >/dev/null 2>&1; then
  merged_policy="$(mktemp)"
  trap 'rm -f "$merged_policy"' EXIT
  jq -s '.[0] * {policies: ((.[0].policies // {}) * (.[1].policies // {}))}' \
    "$firefox_policy_target" "$firefox_policy_source" >"$merged_policy"
  sudo install -m 0644 "$merged_policy" "$firefox_policy_target"
  rm -f "$merged_policy"
  trap - EXIT
else
  sudo install -m 0644 "$firefox_policy_source" "$firefox_policy_target"
fi
echo "Firefox will open https://kkportal.askkingo.ai as its homepage."

