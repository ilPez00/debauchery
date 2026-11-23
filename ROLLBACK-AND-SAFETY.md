# Plan — Rollback & Safety (air)

> Companion to `PLAN.md`, `MIGRATION-niri-to-hyprland.md`, `DISTROBOX.md`,
> `DMS-UNDER-HYPRLAND.md`, `PHYSIS-ADAPTER.md`.

## 1. Guiding principles

1. **niri is never removed.** It stays installed and selectable in ly; the
   Hyprland migration is an additional session, not a replacement.
2. **Every change has an undo.** Configs are backed up before edits; packages
   are removable; the adapter ships an uninstaller.
3. **No blind sudo.** Every `[SYSTEM]` step is reviewed first.
4. **One shell per session.** DMS and the Omarchy Quickshell shell never run in
   the same session.
5. **Distrobox is for tools**, never the compositor or system services.

## 2. Backup locations

| What | Where |
|---|---|
| Pre-migration desktop configs (niri, dms, hypr, quickshell, waybar, fuzzel, ly) | `~/debauchery/backups/2026-11-12/` |
| Session + package inventory at backup time | `~/debauchery/backups/2026-11-12/{sessions-before.txt,pkgs-before.txt}` |
| systemd user units | `~/debauchery/backups/2026-11-12/systemd-user/` |
| Hyprland configs (current) | `~/debauchery/configs/hypr/` |
| Adapter-installed files | `<file>.pre-omarchy` next to each modified file |
| Omarchy port kit backups | `~/.local/share/omarchy/.omarchy-on-debian/backups/` |

## 3. Rollback by phase

### 3.1 Disk cleanup

- Caches (`~/.cache/*`, `~/.npm/_cacache`, `~/.bun/install/cache`, Trash) are
  **rebuildable** — no rollback needed; tools re-fetch on demand.
- The Samsung firmware tars (`~/firmware/OMN/*.tar.md5`) are **re-downloadable**
  from the URLs in `~/firmware/OMN/README.txt`. The generated
  `magisk_patched-31100_asi4y.tar` was kept.
- If the root tier is later run, it only removes apt archives, old journal
  entries and unused flatpak runtimes — none of it is user data.

### 3.2 Hyprland install

```bash
# remove the session and packages
sudo apt remove hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland uwsm
rm -rf ~/.config/hypr
# (the ly .desktop files are removed with the packages)
```

niri and DMS are untouched; the default session stays niri.

### 3.3 Hyprland config

- Current config is copied in `~/debauchery/configs/hypr/`.
- To restore the exact pre-migration state: `cp -a ~/debauchery/backups/2026-11-12/niri ~/.config/niri`.
- The Hyprland config can be edited freely; `Hyprland --verify-config -c <file>`
  validates it without starting a session.

### 3.4 DMS

- DMS config is unchanged by the migration. To roll back DMS behaviour, log into
  niri (DMS starts there exactly as before).
- Plugins disabled under Hyprland can be re-enabled:
  `dms ipc call plugins enable <id>`.

### 3.4a Omarchy layer (plugins, overlay) — Debian stays the base

air does **not** run upstream Omarchy (Arch + Quickshell). `omarchy version`
reports `debauchery 0.3.0 (Debian + DMS + distrobox)`: the command names and
muscle memory are Omarchy's, the implementation is Debian user scope. No
PAM/portal/systemd-system file is touched, so a broken "Omarchy" layer cannot
take the host down.

- Plugins: `omarchy plugin search <query>` (`dms plugins browse` for the full
  419-entry registry), `omarchy plugin install|remove|enable|disable <id>`.
  The 20 installed plugins are pinned with repo + commit in
  `configs/dms-plugins.lock.json`. Refresh after a change with
  `dms plugins lock -o ~/debauchery/configs/dms-plugins.lock.json`; restore the
  exact set with `dms plugins restore configs/dms-plugins.lock.json`
  (`--prune` also removes extras). The Omarchy-style root menu is already in
  that set: plugin `dankMenu`, invoked by `omarchy menu` / Super+Space.
- Keybind overlay (Omarchy's cheatsheet equivalent): Super+Y runs
  `dms ipc call keybinds toggle hypr`; `omarchy menu keybindings` toggles the
  same overlay. Verified live: `KEYBINDS_TOGGLE_SUCCESS: hypr`.
- "Rice" switches: `omarchy rice` / Super+M — `shell dms|noctalia`,
  `menus dankmenu|spotlight|launcher|powermenu|keybinds`, `bar`, `dock`,
  `theme dark|light|next`, `binds omarchy|niri`, `login on|off`.

Return to a known-good Debian shell (no Arch involvement):

```bash
omarchy rice shell dms
omarchy rice binds omarchy
omarchy rice menus dankmenu
omarchy rice theme dark
hyprctl reload
cd ~/debauchery && ./install.sh doctor --json
```

If only the Arch box is broken, `omarchy-arch --stop` — the compositor, DMS
and every shim keep working; never `distrobox rm` for a transient failure.
If a plugin breaks the bar/menu: `omarchy plugin disable <id>` then
`systemctl --user restart dms.service`; worst case
`dms plugins restore ~/debauchery/configs/dms-plugins.lock.json --prune`.
Final fallback: log out and pick niri at ly — it is still installed.

### 3.5 Arch Distrobox

```bash
distrobox stop arch-omarchy
distrobox rm arch-omarchy
podman system prune -f
rm -rf ~/.local/share/distrobox/arch-omarchy-home
```

Nothing installed via `apt` is affected.

### 3.6 Physis adapter

```bash
cd ~/dev/physis-next/adapters/omarchy && ./uninstall.sh
```

### 3.7 Omarchy port kit (if applied later)

```bash
cd ~/omarchy-on-debian        # or wherever it was cloned
./preflight.sh                # see what it touches
# revert system steps manually:
sudo systemctl unmask xdg-desktop-portal-hyprland.service
sudo apt reinstall hyprlock   # if /etc/pam.d/hyprlock was replaced
```

The kit keeps its own backups under `~/.local/share/omarchy/.omarchy-on-debian/backups/`.

## 4. Switching the ly default (and back)

- The default is chosen at the ly screen; `auto_login_session = nil` means no
  automatic session.
- To make Hyprland the default, either pick it once and let ly remember, or set
  `auto_login_session = "hyprland"` in `/etc/ly/config.lua` (needs root).
- To revert: set it back to `"niri"` or clear it.

## 5. Pending root-tier cleanup (was dismissed)

```bash
sudo apt-get clean
sudo journalctl --vacuum-size=50M
sudo flatpak uninstall --unused -y
```

Optional; frees a few GB more. Not required for the migration.

## 6. Emergency

- If Hyprland fails to start: log out, pick niri. Fix the config with
  `Hyprland --verify-config` and `journalctl --user -b`.
- If the root filesystem fills again: re-run the cleanup in
  `notes/2026-11-12.md` §"Disk cleanup", and consider the offload option in
  `PLAN.md` (move cold data to the NAS, symlink the original path).
