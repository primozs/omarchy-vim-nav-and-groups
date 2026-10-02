# Vim nav and window groups

Vim-style `Super+hjkl` window management for [Omarchy](https://omarchy.org/) that understands **Hyprland tab groups**, plus theme-colored group tabs.

Unlike a plain hjkl remap, focus and swap behave correctly when windows are tabbed: cycle tabs inside a group, leave the group at the edge, reorder or eject tabs with Shift, and fold a whole workspace into one tab strip with `Super+G`.

**Zero dependencies** beyond Omarchy’s Hyprland Lua (`hl` / `o`). No bash helpers, no `jq`, no extra packages.

## Keymap

| Keys | Action |
| --- | --- |
| `Super+Q` | Close window (same as stock `Super+W`) |
| `Super+Shift+Q` | Close window (same as `Super+Q` / `Super+W`) |
| `Super+h` / `Super+Left` | Focus left; in a multi-tab group, previous tab (leave group at left edge) |
| `Super+l` / `Super+Right` | Focus right; in a multi-tab group, next tab (leave group at right edge) |
| `Super+k` / `Super+Up` | Focus up; in a multi-tab group, previous tab |
| `Super+j` / `Super+Down` | Focus down; in a multi-tab group, next tab |
| `Super+Shift+h` / `Super+Shift+Left` | Swap/join left; in a multi-tab group, reorder tab left (eject at left edge) |
| `Super+Shift+l` / `Super+Shift+Right` | Swap/join right; in a multi-tab group, reorder tab right (eject at right edge) |
| `Super+Shift+k` / `Super+Shift+Up` | Swap up; in a multi-tab group, move into group above |
| `Super+Shift+j` / `Super+Shift+Down` | Swap down; in a multi-tab group, move into group below |
| `Super+G` | Toggle: fold every window on this workspace into one group, or dissolve every multi-tab group on it |
| `Super+Shift+1..0` | Eject active tab if needed, move that window to workspace, **stay here** |
| `Super+Shift+Alt+1..0` | Same, but **follow** the window |

Stock Omarchy uses the opposite silent/follow pairing for `Shift` vs `Shift+Alt` workspace moves; this plugin matches the silent-on-`Shift` layout.

### Keys this plugin relocates

The Vim layout needs `Super+J`, `Super+K`, `Super+L`, and `Super+G`, so those stock Omarchy actions move to:

| Stock binding | Stock action | New binding |
| --- | --- | --- |
| `Super+J` | Toggle window split | `Super+E` |
| `Super+K` | Keybindings cheatsheet | `Super+Ctrl+Shift+K` |
| `Super+L` | Toggle workspace layout | `Super+D` |
| `Super+G` | Toggle single-window group | workspace fold on `Super+G` (see above) |

## Group look and feel

Applied automatically (theme colors from `~/.local/state/omarchy/current/theme/colors.toml`, with fallbacks):

| Setting | Stock Omarchy | This plugin |
| --- | --- | --- |
| Active tab fill | semi-transparent black | theme accent (opaque) |
| Inactive tab fill | lighter transparent black | theme background (opaque) |
| Active tab text | white | theme darker background |
| Inactive tab text | translucent white | theme foreground |
| `gradients` | `true` | `true` (required — otherwise tab fills do not draw) |
| Tab height | 22 | 25 |
| `gaps_in` / indicator | 5 / height 1 | 0 / height 0 |
| Window opacity | ~0.985 / 0.96 (wallpaper bleeds through tabs) | `1.0 1.0` |
| Window animations | on | off (instant group/move; menus/OSD untouched) |

## Install (stock Omarchy)

**Before installing:** remove any personal Hyprland binds that already own these keys (for example chezmoi `hypr-nav` / `hypr-move` / `hypr-group-workspace` overrides). Otherwise both layers fight over the same chords.

```sh
git clone https://github.com/primozs/omarchy-vim-nav-and-groups.git
cd omarchy-vim-nav-and-groups
./check.sh    # optional smoke: luac, bash -n, omarchy plugin validate
./install.sh
```

That:

1. **Copies** `nav_and_groups.lua` and `group_looknfeel.lua` into `~/.config/hypr/` (mode `644`; backs up collisions)
2. Appends a managed `require("hypr.nav_and_groups")` to `~/.config/hypr/bindings.lua` (follows Chezmoi symlinks; backs up first)
3. Reloads Hyprland and checks for config errors — on failure, rolls the install back

Remove with `./uninstall.sh` (edits bindings in place so a Chezmoi symlink stays intact).

### Future: Omarchy Hyprland plugins

This repo also ships a `manifest.json` with `kinds: ["hyprland"]` so it can load through Omarchy’s plugin manager once [Hyprland plugin support](https://github.com/basecamp/omarchy/discussions/7724) lands upstream:

```sh
omarchy plugin add https://github.com/primozs/omarchy-vim-nav-and-groups.git --enable
```

Until then, use `./install.sh` — stock Omarchy only loads shell (Quickshell) plugins via `omarchy plugin add`.

## Requirements

- Omarchy with Hyprland Lua config (`~/.config/hypr/bindings.lua`)
- Nothing else

## How it differs from `omarchy-vim-bindings`

[catlee/omarchy-vim-bindings](https://github.com/catlee/omarchy-vim-bindings) remaps focus/swap/into-group onto hjkl and leaves tab cycling on stock `Super+Alt+Tab`. This plugin makes **hjkl themselves** group-aware (cycle / exit / reorder / eject), adds workspace fold + eject-on-workspace-move, and ships the opaque theme-colored group bar.

## License

MIT
