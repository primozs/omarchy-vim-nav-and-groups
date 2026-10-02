#!/usr/bin/env bash
# Remove the managed require from ~/.config/hypr/bindings.lua and installed modules.
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
bindings_file="$hypr_dir/bindings.lua"
marker="primozs.vim-nav-and-groups"
require_line="require(\"hypr.nav_and_groups\") -- ${marker}: managed"
managed_header="-- ${marker}: managed module"

modules=(
  nav_and_groups.lua
  group_looknfeel.lua
)

if [[ -f $bindings_file || -L $bindings_file ]]; then
  bindings_real="$(readlink -f -- "$bindings_file")"
  case $bindings_real in
  "$hypr_dir"/*) ;;
  *)
    echo "refusing bindings outside $hypr_dir: $bindings_real" >&2
    exit 1
    ;;
  esac

  tmp="$(mktemp)"
  trap 'rm -f -- "$tmp"' EXIT
  grep -Fvx -- "$require_line" "$bindings_real" \
    | grep -Fvx -- "-- ${marker}: managed begin" \
    | grep -Fvx -- "-- ${marker}: managed end" >"$tmp"
  # In-place write keeps a Chezmoi (or other) symlink intact.
  cat -- "$tmp" >"$bindings_real"
fi

for name in "${modules[@]}"; do
  dest="$hypr_dir/$name"
  if [[ -L $dest ]]; then
    rm -- "$dest"
  elif [[ -f $dest ]] && grep -Fq -- "$managed_header" "$dest"; then
    rm -- "$dest"
  elif [[ -f $dest ]]; then
    echo "Leaving $dest (not a managed install copy)." >&2
  fi
done

hyprctl reload
config_errors="$(hyprctl configerrors)"
if [[ -n $config_errors && $config_errors != "no errors" ]]; then
  echo "Hyprland reported configuration errors:" >&2
  printf '%s\n' "$config_errors" >&2
  exit 1
fi

echo "primozs.vim-nav-and-groups disabled."
