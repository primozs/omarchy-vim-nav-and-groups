#!/usr/bin/env bash
# Install/uninstall safety + rollback checks. No Hyprland session required.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf -- "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
cat >"$tmpdir/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
reload) exit "${FAKE_HYPRCTL_RELOAD_EXIT:-0}" ;;
configerrors) printf '%s\n' "${FAKE_HYPRCTL_CONFIGERRORS:-no errors}" ;;
*) exit 0 ;;
esac
EOF
chmod +x "$tmpdir/bin/hyprctl"

ws="$tmpdir/ws"
mkdir -m 700 -p "$ws"
cp -- "$root/install.sh" "$root/uninstall.sh" \
  "$root/nav_and_groups.lua" "$root/group_looknfeel.lua" "$ws/"
chmod 644 "$ws"/*.lua
chmod 755 "$ws"/*.sh

export HOME="$tmpdir/home"
export XDG_CONFIG_HOME="$tmpdir/xdg"
export PATH="$tmpdir/bin:$PATH"
mkdir -m 700 -p "$XDG_CONFIG_HOME/hypr"
printf -- '-- base\n' >"$XDG_CONFIG_HOME/hypr/bindings.lua"
chmod 600 "$XDG_CONFIG_HOME/hypr/bindings.lua"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Refuse world-writable source file.
chmod 666 "$ws/nav_and_groups.lua"
if (cd "$ws" && ./install.sh) >/dev/null 2>"$tmpdir/err-writable"; then
  fail "expected refuse world-writable source"
fi
grep -q 'group/world-writable source' "$tmpdir/err-writable" \
  || fail "missing world-writable source message"
chmod 644 "$ws/nav_and_groups.lua"

# Refuse group-writable source directory.
chmod 775 "$ws"
if (cd "$ws" && ./install.sh) >/dev/null 2>"$tmpdir/err-dir"; then
  fail "expected refuse group-writable source dir"
fi
grep -q 'group/world-writable source dir' "$tmpdir/err-dir" \
  || fail "missing world-writable source dir message"
chmod 700 "$ws"

# Happy-path install with fake hyprctl.
(cd "$ws" && ./install.sh) >/dev/null
grep -Fq 'primozs.vim-nav-and-groups' "$XDG_CONFIG_HOME/hypr/bindings.lua" \
  || fail "managed require not appended"
[[ -f $XDG_CONFIG_HOME/hypr/nav_and_groups.lua ]] || fail "nav module missing"
[[ -f $XDG_CONFIG_HOME/hypr/group_looknfeel.lua ]] || fail "looknfeel module missing"

# Idempotent require (second install must not duplicate).
(cd "$ws" && ./install.sh) >/dev/null
count="$(grep -Fc 'primozs.vim-nav-and-groups: managed begin' "$XDG_CONFIG_HOME/hypr/bindings.lua" || true)"
[[ $count == 1 ]] || fail "managed block duplicated ($count)"

# Uninstall removes managed require + modules.
(cd "$ws" && ./uninstall.sh) >/dev/null
if grep -Fq 'primozs.vim-nav-and-groups' "$XDG_CONFIG_HOME/hypr/bindings.lua"; then
  fail "managed markers left after uninstall"
fi
[[ ! -e $XDG_CONFIG_HOME/hypr/nav_and_groups.lua ]] || fail "nav module left after uninstall"
[[ ! -e $XDG_CONFIG_HOME/hypr/group_looknfeel.lua ]] || fail "looknfeel left after uninstall"

# Reload failure after writes must roll back.
printf -- '-- base\n' >"$XDG_CONFIG_HOME/hypr/bindings.lua"
printf -- '-- prior-nav\n' >"$XDG_CONFIG_HOME/hypr/nav_and_groups.lua"
printf -- '-- prior-lf\n' >"$XDG_CONFIG_HOME/hypr/group_looknfeel.lua"
chmod 600 "$XDG_CONFIG_HOME/hypr"/*

export FAKE_HYPRCTL_RELOAD_EXIT=1
if (cd "$ws" && ./install.sh) >/dev/null 2>"$tmpdir/err-reload"; then
  fail "expected install failure when hyprctl reload fails"
fi
unset FAKE_HYPRCTL_RELOAD_EXIT
grep -q 'Rolling back install' "$tmpdir/err-reload" || fail "reload failure did not roll back"
grep -q 'prior-nav' "$XDG_CONFIG_HOME/hypr/nav_and_groups.lua" || fail "nav not restored after reload rollback"
grep -q 'prior-lf' "$XDG_CONFIG_HOME/hypr/group_looknfeel.lua" || fail "looknfeel not restored after reload rollback"
if grep -Fq 'primozs.vim-nav-and-groups' "$XDG_CONFIG_HOME/hypr/bindings.lua"; then
  fail "managed require left after reload rollback"
fi

# configerrors path must roll back.
printf -- '-- base\n' >"$XDG_CONFIG_HOME/hypr/bindings.lua"
printf -- '-- prior-nav\n' >"$XDG_CONFIG_HOME/hypr/nav_and_groups.lua"
printf -- '-- prior-lf\n' >"$XDG_CONFIG_HOME/hypr/group_looknfeel.lua"
chmod 600 "$XDG_CONFIG_HOME/hypr"/*

export FAKE_HYPRCTL_CONFIGERRORS='simulated config error'
if (cd "$ws" && ./install.sh) >/dev/null 2>"$tmpdir/err-config"; then
  fail "expected install failure on configerrors"
fi
unset FAKE_HYPRCTL_CONFIGERRORS
grep -q 'Rolling back install' "$tmpdir/err-config" || fail "configerrors did not roll back"
grep -q 'prior-nav' "$XDG_CONFIG_HOME/hypr/nav_and_groups.lua" || fail "nav not restored after configerrors rollback"
if grep -Fq 'primozs.vim-nav-and-groups' "$XDG_CONFIG_HOME/hypr/bindings.lua"; then
  fail "managed require left after configerrors rollback"
fi

# Uninstall leaves unmanaged module copies alone.
printf -- '-- base\nrequire("hypr.nav_and_groups") -- primozs.vim-nav-and-groups: managed\n' \
  >"$XDG_CONFIG_HOME/hypr/bindings.lua"
printf -- '-- user override, not managed\n' >"$XDG_CONFIG_HOME/hypr/nav_and_groups.lua"
printf -- '-- primozs.vim-nav-and-groups: managed module\n' >"$XDG_CONFIG_HOME/hypr/group_looknfeel.lua"
chmod 600 "$XDG_CONFIG_HOME/hypr"/*
(cd "$ws" && ./uninstall.sh) >/dev/null 2>"$tmpdir/err-unmanaged"
grep -q 'Leaving .*nav_and_groups.lua' "$tmpdir/err-unmanaged" \
  || fail "expected leave-unmanaged warning"
[[ -f $XDG_CONFIG_HOME/hypr/nav_and_groups.lua ]] || fail "unmanaged nav was deleted"
[[ ! -e $XDG_CONFIG_HOME/hypr/group_looknfeel.lua ]] || fail "managed looknfeel not removed"

echo "test/install_safety.sh: ok"
