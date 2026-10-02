#!/usr/bin/env bash
# Enable on stock Omarchy: copy Lua modules into ~/.config/hypr and require them.
# No extra packages. Hyprland plugin-manager support (kinds: hyprland) is optional/future.
set -euo pipefail
umask 077

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
bindings_file="$hypr_dir/bindings.lua"
marker="primozs.vim-nav-and-groups"
require_line="require(\"hypr.nav_and_groups\") -- ${marker}: managed"

modules=(
  nav_and_groups.lua
  group_looknfeel.lua
)

bindings_backup=""
declare -a module_backups=()
declare -a modules_written=()
require_appended=0

rollback() {
  # Avoid recursion if restore commands fail under set -e / ERR.
  trap - ERR
  echo "Rolling back install…" >&2
  if ((require_appended)) && [[ -n $bindings_backup && -f $bindings_backup ]]; then
    # Restore through the live path so a bindings.lua symlink keeps pointing
    # at the Chezmoi (or other) source after we restore its contents.
    cat -- "$bindings_backup" >"$bindings_file"
  fi
  local i
  for i in "${!modules_written[@]}"; do
    local dest="${modules_written[$i]}"
    local bak="${module_backups[$i]:-}"
    rm -f -- "$dest"
    if [[ -n $bak && -e $bak ]]; then
      mv -- "$bak" "$dest"
    fi
  done
  hyprctl reload >/dev/null 2>&1 || true
}

# Owner + not group/world-writable, including the parent directory (TOCTOU).
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

assert_safe_source() {
  local src=$1
  [[ -f $src ]] || {
    echo "missing $src" >&2
    return 1
  }
  assert_safe_path "$src" "source"
  assert_safe_path "$(dirname -- "$src")" "source dir"
}

for name in "${modules[@]}"; do
  assert_safe_source "$repo_dir/$name"
done

[[ -f $bindings_file || -L $bindings_file ]] || {
  echo "Missing Hyprland bindings file: $bindings_file" >&2
  exit 1
}

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

mkdir -p "$hypr_dir"

# Any failure after this point restores prior config.
trap 'rollback; exit 1' ERR

for name in "${modules[@]}"; do
  src="$repo_dir/$name"
  # Re-check immediately before copy (closes the validation→install window).
  assert_safe_source "$src"
  dest="$hypr_dir/$name"
  bak=""
  if [[ -e $dest || -L $dest ]]; then
    bak="$dest.bak.$(date +%s)"
    mv -- "$dest" "$bak"
    chmod 600 -- "$bak" 2>/dev/null || true
    echo "Backed up existing $name to $bak"
  fi
  install -m 644 -- "$src" "$dest"
  modules_written+=("$dest")
  module_backups+=("$bak")
done

if ! grep -Fqx -- "$require_line" "$bindings_file"; then
  bindings_backup="$bindings_file.bak.$(date +%s)"
  # Follow symlink: copy the real file contents for backup.
  cp -- "$bindings_real" "$bindings_backup"
  chmod 600 -- "$bindings_backup"
  printf '\n-- %s: managed begin\n%s\n-- %s: managed end\n' "$marker" "$require_line" "$marker" >>"$bindings_file"
  require_appended=1
  echo "Backed up bindings to $bindings_backup"
fi

# Non-zero reload triggers ERR → rollback. Config errors roll back explicitly.
hyprctl reload
config_errors="$(hyprctl configerrors)"
if [[ -n $config_errors && $config_errors != "no errors" ]]; then
  echo "Hyprland reported configuration errors:" >&2
  printf '%s\n' "$config_errors" >&2
  rollback
  exit 1
fi

trap - ERR
echo "primozs.vim-nav-and-groups enabled."
