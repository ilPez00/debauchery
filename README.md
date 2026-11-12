# debauchery — air system repo

Working repo for the **air** host (MacBook Air 2016, Debian 13 + niri/DMS):
plans, options analysis, backups and helper scripts for the Omarchy integration.

## Contents

| Path | What |
|---|---|
| `PLAN.md` | Long-form plan: options inventory, recommended architecture, Physis adapter, phased implementation, guidelines, risks, resources |
| `scripts/backup-desktop.sh` | Back up `~/.config/{niri,dms,hypr,quickshell,waybar,fuzzel,ly}` + session/unit inventory |
| `scripts/create-arch-distrobox.sh` | Create the Arch Distrobox (PLAN.md Phase 1) |
| `backups/` | Dated config backups (local; git-ignored) |
| `notes/` | Running log of applied changes |

## Status

**Nothing applied yet.** See `PLAN.md` §13 (verification log) and §12 (open
decisions). The only pre-existing artifact on the host is the 2026-11-03
`omarchy-debian` dry-run log (`~/.local/state/omarchy-debian/install.log`).

## Quick start

1. Read `PLAN.md` §2 (executive summary) and §12 (open decisions).
2. Run `scripts/backup-desktop.sh` before any phase.
3. Recommended first change: Phase 1 — Arch Distrobox (lowest risk, additive).
4. Log every applied phase in `notes/2026-11-12.md`.

## Safety

- Every `[SYSTEM]` step in `PLAN.md` is flagged; review before running.
- niri stays the default session; anything new is an opt-in ly session.
- Distrobox is for tools, never for the compositor or system services.
