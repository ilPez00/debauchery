# debauchery — air system repo

Working repo for **air** (MacBook Air 2016, Debian 13 + niri/DMS): plans,
system state, configs, backups and helper scripts for the Omarchy / Hyprland
integration.

## Documents

| Document | Contents |
|---|---|
| `STATE.md` | Verified current system state: host, sessions, packages, configs, DMS, distrobox, disk, pending items |
| `PLAN.md` | Omarchy integration plan: options A–G with verdicts, recommended architecture, phased implementation, guidelines, risks, resources |
| `MIGRATION-niri-to-hyprland.md` | niri → Hyprland migration: behavior model mapping, full hotkey table, config translation, phases, rollback |
| `DISTROBOX.md` | Arch Distrobox plan: create/configure/use/AUR/GUI export/teardown/troubleshooting |
| `DMS-UNDER-HYPRLAND.md` | DMS under Hyprland: compositor detection, keybind mapping, plugin swap, screenshots, verification |
| `PHYSIS-ADAPTER.md` | Physis omarchy adapter: architecture, build, deploy, verify, installer bug, known mismatches |
| `ROLLBACK-AND-SAFETY.md` | Rollback per phase, safety rules, backup locations, emergency steps |

## Directories

| Path | What |
|---|---|
| `configs/hypr/` | Current Hyprland config (`hyprland.conf`, `binds.conf`, `monitors.conf`, `autostart.conf`, `rules.conf`, `extra.conf`) |
| `scripts/` | `backup-desktop.sh`, `create-arch-distrobox.sh` |
| `notes/` | Status log (applied changes, disk cleanup account) |
| `backups/` | Dated config backups (git-ignored) |

## Status (2026-11-12)

- Hyprland 0.55.2 installed; config written and `Hyprland --verify-config` → **config ok**.
- ly offers `hyprland.desktop` / `hyprland-uwsm.desktop`; **niri is still the default**.
- Arch Distrobox `arch-omarchy` creation started (image pull).
- Disk reclaimed from 1.4 GB free to 23 GB free.
- Nothing applied that breaks niri; DMS config untouched.

## Next

1. Log into **Hyprland** from ly and verify (see `DMS-UNDER-HYPRLAND.md` §7).
2. Swap the DMS niri plugins for Hyprland-aware ones if they error.
3. Only then make Hyprland the ly default.
4. Optional: Physis adapter, Omarchy shell, Lua config port.

## Safety

- Every `[SYSTEM]` step is flagged; review before running.
- niri stays the default until Hyprland is verified.
- Distrobox is for tools only, never the compositor or system services.
