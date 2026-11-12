# air — System State (detailed)

> Snapshot 2026-11-12, after the Hyprland migration groundwork and a disk cleanup.
> Every item below was verified by command output, not assumed.

## 1. Host

| | |
|---|---|
| Hostname | `air` |
| Model | Apple `MacBookAir7,2` (MacBook Air 2016) |
| CPU | Intel Core i5-5350U @ 2.90 GHz |
| GPU | Intel HD Graphics 6000 |
| OS | Debian 13.7 (trixie) |
| Kernel | 7.2.12+deb13-amd64 |
| Root fs | `/dev/mapper/air--vg-root`, 104 GB |
| Disk free | 23 GB (77% used) — was 1.4 GB (99%) before cleanup |
| Root access | `sudo` needs a password; `pkexec` needs an Authenticate click |

## 2. Display sessions (ly)

| Session | File | Notes |
|---|---|---|
| niri | `niri.desktop` | current default; niri + DMS |
| niri (DMS) | `niri-duks.desktop` | niri + DMS |
| niri (Noctalia) | `niri-noctalia.desktop` | niri + Noctalia shell |
| Hyprland | `hyprland.desktop` | added by the hyprland package |
| Hyprland (uwsm) | `hyprland-uwsm.desktop` | added by the uwsm package |

- Display manager: **ly** (`/etc/ly/config.lua`, `waylandsessions = "/usr/share/wayland-sessions"`).
- `auto_login_session = nil` → no automatic session; the user picks at login.
- **ly auto-logins `gio` into `hyprland`** (set 2026-11-12: `auto_login_session = "hyprland"`,
  `auto_login_user = "gio"`; previous config backed up as `/etc/ly/config.lua.bak-20261112`).
  niri stays installed and untouched — log out once and the normal session menu appears.
- `~/.config/hypr/autostart.conf` imports the compositor env into systemd and starts
  `graphical-session.target`, which is what pulls in `dms.service`
  (`Requisite=graphical-session.target`; `start-hyprland` does not start that target).

## 3. Installed desktop packages

| Package | Version | Source |
|---|---|---|
| hyprland | 0.55.2+ds-1~bpo13+1 | trixie-backports |
| hyprlock | 0.9.6-1~bpo13+1 | trixie-backports |
| hypridle | 0.1.8-1~bpo13+1 | trixie-backports |
| hyprpaper | 0.8.4-1~bpo13+1 | trixie-backports |
| xdg-desktop-portal-hyprland | 1.4.1-1~bpo13+1 | trixie-backports |
| uwsm | 0.26.7+ds-2~bpo13+1 | trixie-backports |
| cargo / rustc | 1.96.1+dfsg1-2~bpo13+1 | trixie-backports |
| distrobox | 1.8.1.2-1 | trixie |
| podman | 5.4.2+ds1-2+b2 | trixie |
| dms | 2.1.2db1 | danklinux repo |
| quickshell | 0.3.2 | danklinux opensuse repo |

Binaries: `/usr/bin/{Hyprland,hyprctl,hyprlock,hypridle,hyprpaper,distrobox,podman,cargo,rustc}`.

## 4. Hyprland config (`~/.config/hypr/`)

| File | Contents |
|---|---|
| `hyprland.conf` | general/decoration/animations/input/misc/dwindle; sources the rest |
| `monitors.conf` | `eDP-1, 1440x900@60, 0x0, 1` + catch-all |
| `autostart.conf` | `exec-once = /home/gio/.local/bin/physis-selector` |
| `binds.conf` | full niri+DMS → Hyprland keybind translation |
| `rules.conf` | window rules (0.53+ `windowrule {}` syntax) |
| `extra.conf` | sourced by the Physis adapter |

Validation: `Hyprland --verify-config -c ~/.config/hypr/hyprland.conf` → **config ok**.

Note: Hyprland 0.55 is Lua-first; this config is hyprlang, which still works but
should be ported to Lua eventually (see `plans/`).

## 5. DMS state

- Started as a systemd user service: `dms.service`, `PartOf=graphical-session.target`,
  `ExecStart=/usr/bin/dms run --session`. It follows whichever compositor session
  is active (niri or Hyprland).
- Config: `~/.config/dms/settings.json` — theme `chadracula`, `matugenScheme
  scheme-tonal-spot`, font `MesloLGS NF`.
- IPC surface (`dms ipc call <target> <function>`): `audio`, `bar`, `brightness`,
  `clipboard`, `color-picker`, `control-center`, `dankMenu`, `dash`, `dock`,
  `file`, **`hypr`** (`openOverview`, `closeOverview`, `toggleOverview`,
  `openBinds`, `closeBinds`, `toggleBinds`), `inhibit`, `keybinds`, `launcher`,
  `lock`, `mic`, `mpris`, `night`, **`niri`** (screenshots, touchpad OSD),
  `notifications`, `outputs`, `powermenu`, `powerprofile`, `processlist`, `scratchpad`,
  `screenshot`, `settings`, `spotlight`, `spotlight-bar`, `systemupdater`, `theme`,
  `tmux`, `toast`, `tray`, `wallpaper`, `welcome`, `wellbeing`, `widget`,
  `window-rules`, `workspace-rename`.
- Installed plugins: `aiOverviewControl`, `animationRotate`, `cavaVisualizer`,
  `clipboardPlus`, `cpuThermalIndicator`, `dankKDEConnect`, `dankMenu`, `dankscale`,
  `desktopCommand`, `displayModes`, `enderPulse`, `networkIndicator`,
  **`niriWindows`**, **`niriWorkspaceBar`**, `storageMonitor`.
- The two niri-named plugins are niri-specific; under Hyprland they need replacing
  (see `DMS-UNDER-HYPRLAND.md`).

## 6. niri state (unchanged, still working)

- `niri 26.04`, config `~/.config/niri/config.kdl` with includes `dms/*.kdl` and
  the function-row binds (F1–F12 + XF86).
- Full backup of the pre-migration config: `~/debauchery/backups/2026-11-12/`.

## 7. Distrobox / podman

- `distrobox 1.8.1.2`, `podman 5.4.2`, rootless (`podman info` → `Rootless: true`).
- Subuids present: `gio:100000:65536` in `/etc/subuid` and `/etc/subgid`.
- Container `arch-omarchy` — **created 2026-11-12**, image `quay.io/archlinux/archlinux:latest`,
  home `~/.local/share/distrobox/arch-omarchy-home`. The original image
  (`quay.io/toolbx/arch-toolbox:latest`) is a *schema1* manifest that podman can no
  longer pull; `quay.io/toolbx-images/...` answers UNAUTHORIZED — do not retry those.
- The container user (`gio`, uid 1000) had **no sudo rights and no password**, so
  `pacman` could not install anything. A passwordless-sudo drop-in
  (`/etc/sudoers.d/gio` inside the container) was applied 2026-11-12 to fix this.
- Toolchain **installed and verified 2026-11-12**: `git`, `lazygit`, `btop`,
  `yazi`, `fzf`, `ripgrep`, `fd`, `bat`, `zoxide`, `nvim` — all present.
  No AUR helper yet (`paru`/`yay` not installed).

## 8. Disk (after cleanup)

- Freed from 1.4 GB → 23 GB free by removing rebuildable caches and the
  re-downloadable Samsung firmware tars. Full account in `notes/2026-11-12.md`.
- Still large, deliberately untouched: `~/.local/share/physis-backups/pansa`
  (6.8 GB backup repo), `~/.ollama` (5.5 GB models), `~/.npm-global` (3.2 GB),
  `~/dev/physis-next/.git` (6.5 GB), `/var/lib/flatpak` (7.4 GB, needs root).

## 9. Pending / not done

- [ ] Live Hyprland login test (DMS, overview, function row, media, lock).
- [ ] Swap DMS niri plugins for Hyprland-aware ones.
- [x] Make Hyprland the ly default (autologin set 2026-11-12; live verification still pending).
- [ ] Physis omarchy adapter deployment (needs Hyprland + cargo; see `PHYSIS-ADAPTER.md`).
- [ ] Optional: Omarchy Quickshell shell in its own session (see `PLAN.md`).
- [ ] Optional: Lua port of the Hyprland config.
- [ ] Optional: root-tier cleanup (`apt-get clean`, journal vacuum, `flatpak uninstall --unused`).
