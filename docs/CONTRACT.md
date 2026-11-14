# The Omarchy contract on Debian

What "feels like Omarchy" means here, and what is deliberately not ported.

Omarchy is an Arch distribution whose shell is Quickshell QML. air is Debian 13
with DMS (also Quickshell, compositor-agnostic) on Hyprland. Copying Omarchy's
packaging onto Debian is what the port kits in `PLAN.md` §5 attempt, and it costs
`/etc/pam.d` edits and a masked `xdg-desktop-portal-hyprland` — the two documented
ways to break locking and screen sharing.

This layer copies the **interface** instead:

* the command names (`omarchy-menu`, `omarchy-capture-screenshot`, …),
* the key bindings,
* the package verbs (`omarchy-pkg-add`, `pacman`, `yay`, `paru`),

and retargets each one at whatever air actually runs: DMS IPC, Hyprland
dispatchers, apt, brightnessctl, `arch-omarchy` via podman.

Result: Omarchy muscle memory, Debian stability, no system-file surgery.

## Tier 1 — implemented

Backed by `configs/bin/omarchy-shim`, deployed by `scripts/11-omarchy-shims.sh`
as `~/.local/bin/omarchy-<verb>`. `omarchy-shim --check` prints every backend.

| Verb | Target |
|---|---|
| `omarchy-menu` | `dms ipc call dankMenu toggle root` |
| `omarchy-menu-keybindings` | `dms ipc call keybinds toggle hypr` |
| `omarchy-menu-power`, `omarchy-menu-system` | `dms ipc call powermenu toggle` |
| `omarchy-menu-clipboard` | `dms ipc call clipboard toggle` |
| `omarchy-capture-screenshot [region\|full\|all\|window\|last]` | `dms screenshot` |
| `omarchy-capture-screenrecording` | `wf-recorder` + `slurp` (optional dep) |
| `omarchy-capture-text` | `grim` + `slurp` + `tesseract` + `wl-copy` (optional deps) |
| `omarchy-brightness-display [+N%\|-N%\|N%\|up\|down]` | `dms ipc call brightness` |
| `omarchy-brightness-keyboard [up\|down\|cycle]` | `brightnessctl -d smc::kbd_backlight` |
| `omarchy-audio-output-volume [+N\|-N\|N%]` | `dms ipc call audio` |
| `omarchy-audio-output-switch` | `dms ipc call audio cycleoutput` |
| `omarchy-audio-input-mute` | `dms ipc call audio micmute` |
| `omarchy-media [play-pause\|next\|previous]` | `dms ipc call mpris` |
| `omarchy-lock` | `dms ipc call lock lock` |
| `omarchy-night-toggle` | `dms ipc call night toggle` |
| `omarchy-theme-toggle` | `dms ipc call theme toggle` |
| `omarchy-notifications-toggle` | `dms ipc call notifications toggleDoNotDisturb` |
| `omarchy-toggle-touchpad [on\|off]` | `hyprctl keyword device[<name>]:enabled` |
| `omarchy-layout-toggle` | `hyprctl keyword general:layout` (dwindle ↔ master) |
| `omarchy-window-close-all` | `hyprctl dispatch closewindow` per client |
| `omarchy-cmd-terminal-cwd` | focused window pid → `/proc/<pid>/cwd` |
| `omarchy-launch-browser [url]` | `dms ipc call defaultApp browser`, else `xdg-open` |

Package verbs live in `configs/bin/omarchy-pkg` (see `DISTROBOX.md` §12):
`add`, `drop`, `present`, `missing`, `install`, `remove`, `aur-add`,
`aur-install`, plus `pacman` / `yay` / `paru` shims into `arch-omarchy`.

## Tier 2 — skipped on purpose

`omarchy-install-*`, `omarchy-remove-*`, gaming, dictation, webapp launchers,
`linux-omarchy`, PAM and portal steps. They assume Arch, systemd system units and
Omarchy's own shell; none of them are needed for the interface, and several are
the exact steps that break a working session.

## Keybind parity

`configs/binds/omarchy.conf` is the Omarchy profile: the key list comes from
upstream `config/hypr/default/bindings/{tiling,utilities,media,clipboard}.lua`.

Switch: `./install.sh binds omarchy` — back: `./install.sh binds niri`.

### Matches

`SUPER+Space` menu · `SUPER+Q`/`SUPER+W` close · `SUPER+F` fullscreen ·
`SUPER+T` float · `SUPER+J` split · `SUPER+K` keybindings · `SUPER+L` layout
cycle · `SUPER+P` pseudo · `SUPER+S` scratchpad · `SUPER+grave` quake console ·
`SUPER+1..9` workspaces · `SUPER+Tab` next workspace · `SUPER+Return` terminal ·
`ALT+Tab` cycle · `PRINT` screenshot.

### Deviations, and why

| # | Key | Omarchy | air | Why |
|---|---|---|---|---|
| D1 | `SUPER+O` | pop window (float + pin) | DMS overview | no clean Hyprland primitive; overview is the better action on 1440x900 |
| D2 | `SUPER+V` | universal paste (key forwarding) | clipboard manager | forwarding Ctrl+V into the focused window is fragile; the manager is a superset |
| D3 | `SUPER+comma` | notification act/dismiss | DND toggle | DMS has no "act on last notification" IPC |
| D4 | `SUPER+SHIFT+E` | email webapp | exit session | a session exit key must exist; Omarchy's is `SUPER+ESCAPE` + menu |
| D5 | `SUPER+E` | unbound | browser | kept from air's habit; costs nothing |
| D6 | `SUPER+A` | universal select-all | control centre | same key-forwarding reason as D2 |
| D7 | `SUPER+X` | universal cut | power menu | same; `omarchy-menu-power` lives on `SUPER+ESCAPE` |

Everything else is the niri profile's problem, not this one: `binds niri` restores
`H/J/K/L` focus, `SUPER+T` terminal and the rest exactly as they were.

## Stability budget

This layer never:

* writes to `/etc/pam.d`, masks a portal, or replaces a systemd **system** unit,
* installs a kernel, a compositor or a display manager from the AUR,
* runs the compositor or a portal inside the container,
* deletes a config without a `.pre-debauchery` copy.

Everything user-scope is reversible with `./install.sh uninstall`; container and
compositor are removed by `scripts/07-rollback.sh`.

## Adding a verb

1. add the name to `VERBS` in `configs/bin/omarchy-shim`,
2. add its `case` branch that calls a DMS IPC target or a Debian binary,
3. `./scripts/11-omarchy-shims.sh install` — it reads `--list` and links the rest.

No second list to keep in sync.
