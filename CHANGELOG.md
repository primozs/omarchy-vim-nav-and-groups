# Changelog

All notable changes to this project are documented here. Version numbers follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-02

First release for stock Omarchy / Hyprland: Vim-style `Super+hjkl` navigation that understands tab groups, workspace fold, theme-colored group bar, and copy-on-install with rollback.

### Added

- Group-aware focus and swap on `Super+hjkl` (and arrow aliases): cycle tabs inside multi-tab groups, exit at edges, reorder or eject with `Super+Shift+hjkl`
- Vertical tab eject above/below the group via dwindle preselect (`Super+Shift+j/k`)
- `Super+G` workspace fold: merge all windows on a workspace into one group, or dissolve groups on toggle
- Workspace moves with eject-first behavior (`Super+Shift+1..0` silent, `Super+Shift+Alt+1..0` follow)
- Theme-colored opaque group bar and instant window motion (`group_looknfeel.lua`)
- Relocated stock Omarchy bindings (`Super+E`, `Super+D`, `Super+Ctrl+Shift+K`) documented in README
- `install.sh` / `uninstall.sh` with Chezmoi-safe bindings edits, backups, and Hyprland reload validation
- `manifest.json` for future Omarchy Hyprland plugin manager loading
- `test/install_safety.sh` (fake `hyprctl`) wired into `check.sh`
- Manual post-install smoke checklist in README

### Fixed

- Refuse group/world-writable or non-owned install sources (mode-bit check)
- Match Omarchy stock group bar tab height (22)
- Transactional install/uninstall: rollback on `hyprctl reload` failure and config errors, not only the latter
- Re-stat sources before copy; validate bindings path ownership and permissions

### Security

- Tighter install trust model: source directory checks, `umask 077`, restricted backup permissions
- Uninstall backs up before mutating and restores on failure

[1.0.0]: https://github.com/primozs/omarchy-vim-nav-and-groups/releases/tag/v1.0.0
