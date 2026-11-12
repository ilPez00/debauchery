# debauchery — air system repo

Plans, scripts and configs for the **air** host (MacBook Air 2016, Debian 13):
the niri → Hyprland migration, the Arch Distrobox, DMS under Hyprland, the
Physis omarchy adapter, and the Omarchy integration options.

## Documents

| Document | Contents |
|---|---|
| `STATE.md` | Verified system state: host, sessions, packages, configs, DMS, distrobox, disk, pending |
| `PLAN.md` | Omarchy integration: options A–G verdicts, architecture, phases, risks, resources |
| `MIGRATION-niri-to-hyprland.md` | niri → Hyprland: behavior mapping, hotkey table, config translation, rollback |
| `DISTROBOX.md` | Arch Distrobox: create/configure/use/AUR/GUI export/teardown |
| `DMS-UNDER-HYPRLAND.md` | DMS under Hyprland: detection, keybinds, plugin swap, screenshots |
| `PHYSIS-ADAPTER.md` | Physis adapter: architecture, build, deploy, installer bug, mismatches |
| `ROLLBACK-AND-SAFETY.md` | Per-phase rollback, safety rules, emergency steps |

## Scripts (everything that was done)

| Script | What it does |
|---|---|
| `scripts/01-hyprland-install.sh` | Install Hyprland + session stack + Rust + distrobox/podman (root) |
| `scripts/02-hyprland-config.sh` | Deploy `configs/hypr/*.conf` → `~/.config/hypr/` (backs up first) |
| `scripts/03-arch-distrobox.sh` | Create + provision the Arch Distrobox (fixes sudo, installs toolchain) |
| `scripts/04-disk-reclaim.sh` | Reclaim disk (caches + re-downloadable firmware tars; `--with-root` for the root tier) |
| `scripts/05-function-row.sh` | MacBook F1–F12 / fnmode guidance (1 = macOS-like, 2 = current) |
| `scripts/06-physis-adapter.sh` | Physis adapter: test / dry-run / install / uninstall |
| `scripts/07-rollback.sh` | Per-phase rollback commands |
| `scripts/backup-desktop.sh` | Back up desktop configs before changes |
| `scripts/create-arch-distrobox.sh` | Thin wrapper for the distrobox create step |

## Directories

| Path | What |
|---|---|
| `configs/hypr/` | Live Hyprland config (`hyprland.conf`, `binds.conf`, `monitors.conf`, `autostart.conf`, `rules.conf`, `extra.conf`) |
| `notes/` | Status log (applied changes, disk cleanup account) |
| `backups/` | Dated config backups (git-ignored) |

## Status (2026-11-12)

- Hyprland 0.55.2 installed; config verifies clean (`Hyprland --verify-config`).
- ly auto-logins into Hyprland; niri still installed and selectable.
- Arch Distrobox `arch-omarchy` running with the toolchain installed.
- Disk reclaimed from 1.4 GB free to ~22 GB free.
- Physis adapter **deployed** (Phase 5): binaries, `physis-omarchy.conf` sourced
  from `extra.conf`, user unit, desktop entry. Installer `--dry-run` bug fixed;
  `$mainMod` defined; HUD on `SUPER+SHIFT G` (H was `movewindow, l`).
- DMS config untouched; the niri session remains a working fallback.

## Next

1. Log into Hyprland and verify (see `DMS-UNDER-HYPRLAND.md` §7).
2. In that session: `SUPER+SHIFT P/G/O` + `$XDG_RUNTIME_DIR/physis-omarchy.sock`
   — the last unverified adapter item.
3. Swap the DMS niri plugins if they error under Hyprland.
4. Optional: Omarchy shell in its own session, Lua config port.

## Safety

- Every `[SYSTEM]` step is flagged; review before running.
- niri stays installed and selectable until Hyprland is verified.
- Distrobox is for tools only, never the compositor or system services.
