#!/usr/bin/env bash
# Smoke checks for CI / local verify. No Hyprland session required.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$root"

luac -p nav_and_groups.lua group_looknfeel.lua
bash -n install.sh uninstall.sh check.sh
omarchy plugin validate "$root"
echo "check.sh: ok"
