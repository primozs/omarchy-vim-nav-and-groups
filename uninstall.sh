#!/usr/bin/env bash
# Remove the managed require from ~/.config/hypr/bindings.lua and installed modules.
set -euo pipefail
umask 077

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

bindings_backup=""
bindings_edited=0
tmp=""
declare -a removed_modules=()
declare -a removed_backups=()

cleanup_tmp() {
  if [[ -n $tmp && -e $tmp ]]; then
    rm -f -- "$tmp"
  fi
  tmp=""
}

rollback() {
  trap - ERR
  cleanup_tmp
  echo "Rolling back uninstall…" >&2
  if ((bindings_edited)) && [[ -n $bindings_backup && -f $bindings_backup ]]; then
    cat -- "$bindings_backup" >"$bindings_file"
  fi
  local i
  for i in "${!removed_modules[@]}"; do
    local dest="${removed_modules[$i]}"
    local bak="${removed_backups[$i]:-}"
    if [[ -n $bak && -e $bak ]]; then
      mv -- "$bak" "$dest"
    fi
  done
  hyprctl reload >/dev/null 2>&1 || true
}

assert_safe_path() {
  local path=$1
  local label=${2:-path}
  [[ -e $path || -L $path ]] || {
    echo "missing $label: $path" >&2
    return 1
  }
  local mode owner
  mode="$(stat -c '%a' "$path")"
  owner="$(stat -c '%u' "$path")"
  [[ $owner == "$(id -u)" ]] || {
    echo "refusing non-owned $label: $path" >&2
    return 1
  }
  if (( (8#$mode & 8#022) != 0 )); then
    echo "refusing group/world-writable $label: $path (mode $mode)" >&2
    return 1
  fi
}

trap 'rollback; exit 1' ERR

if [[ -f $bindings_file || -L $bindings_file ]]; then
  bindings_real="$(readlink -f -- "$bindings_file")"
  case $bindings_real in
  "$hypr_dir"/*) ;;
  *)
    echo "refusing bindings outside $hypr_dir: $bindings_real" >&2
    exit 1
    ;;
  esac

  assert_safe_path "$bindings_real" "bindings"
  assert_safe_path "$(dirname -- "$bindings_real")" "bindings dir"

  bindings_backup="$bindings_file.bak.uninstall.$(date +%s)"
  cp -- "$bindings_real" "$bindings_backup"
  chmod 600 -- "$bindings_backup"

  tmp="$(mktemp)"
  grep -Fvx -- "$require_line" "$bindings_real" \
    | grep -Fvx -- "-- ${marker}: managed begin" \
    | grep -Fvx -- "-- ${marker}: managed end" >"$tmp"
  # In-place write keeps a Chezmoi (or other) symlink intact.
  cat -- "$tmp" >"$bindings_file"
  bindings_edited=1
  cleanup_tmp
fi

for name in "${modules[@]}"; do
  dest="$hypr_dir/$name"
  if [[ -L $dest ]]; then
    bak="$dest.bak.uninstall.$(date +%s)"
    cp -P -- "$dest" "$bak"
    rm -- "$dest"
    removed_modules+=("$dest")
    removed_backups+=("$bak")
  elif [[ -f $dest ]] && grep -Fq -- "$managed_header" "$dest"; then
    bak="$dest.bak.uninstall.$(date +%s)"
    mv -- "$dest" "$bak"
    chmod 600 -- "$bak" 2>/dev/null || true
    removed_modules+=("$dest")
    removed_backups+=("$bak")
  elif [[ -f $dest ]]; then
    echo "Leaving $dest (not a managed install copy)." >&2
  fi
done

hyprctl reload
config_errors="$(hyprctl configerrors)"
if [[ -n $config_errors && $config_errors != "no errors" ]]; then
  echo "Hyprland reported configuration errors:" >&2
  printf '%s\n' "$config_errors" >&2
  rollback
  exit 1
fi

trap - ERR
echo "primozs.vim-nav-and-groups disabled."
