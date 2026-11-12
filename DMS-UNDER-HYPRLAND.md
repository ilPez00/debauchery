# Plan — DMS under Hyprland (air)

> Companion to `MIGRATION-niri-to-hyprland.md`. DMS (Dux Modular Shell) is the
> desktop shell on air; this plan covers how it behaves once the session
> compositor is Hyprland instead of niri.

## 1. What DMS provides (compositor-agnostic)

DMS runs as a systemd user service and is **not** tied to niri:

```
~/.config/systemd/user/dms.service
  PartOf=graphical-session.target
  WantedBy=graphical-session.target
  ExecStart=/usr/bin/dms run --session
```

So it starts in **any** graphical session — niri, Hyprland, or uwsm-wrapped
Hyprland — and provides: the bar, dock, launcher (`spotlight`), unified menu
(`dankMenu`), notifications, OSDs, control center, clipboard, color picker,
notepad, lock screen, wallpaper, power menu, process list, settings, and the
plugin registry.

## 2. Compositor detection

- DMS keys off the session environment. The Hyprland config sets
  `env = XDG_CURRENT_DESKTOP,Hyprland` so DMS knows it is not on niri.
- Hyprland-specific IPC surface (`dms ipc call hypr ...`):
  `openOverview`, `closeOverview`, `toggleOverview`, `openBinds`, `closeBinds`,
  `toggleBinds`.
- niri-specific IPC surface (`dms ipc call niri ...`): `screenshot`,
  `screenshotScreen`, `screenshotWindow`, `showTouchpadOsd`. These are niri-only.

## 3. Keybind mapping for the shell

| niri (current) | Hyprland (target) | Command |
|---|---|---|
| `Mod+Tab` / `Mod+O` overview | same keys | `dms ipc call hypr toggleOverview` |
| `Mod+Y` keybinds overlay | same key | `dms ipc call keybinds toggle hypr` |
| `Mod+Space` menu | same key | `dms ipc call dankMenu toggle root` |
| `Mod+Z` launcher | same key | `dms ipc call spotlight toggle` |
| `Mod+A` control center | same key | `dms ipc call control-center toggle` |
| `Mod+D` dash | same key | `dms-dash-toggle` (wrapper; needs an empty tab arg) |
| `Mod+Alt+L` lock | same key | `dms ipc call lock lock` |
| `Mod+X` power menu | same key | `dms ipc call powermenu toggle` |
| `Mod+Alt+N` night mode | same key | `dms ipc call night toggle` |
| `Mod+P` display profile | same key | `dms ipc call outputs cycleProfile` |
| `Print` / `Ctrl+Print` screenshots | same keys | `dms screenshot ...` (verify under Hyprland) |

All of these are already written in `~/.config/hypr/binds.conf`.

## 4. Plugins: niri vs Hyprland

Installed DMS plugins (15): `aiOverviewControl`, `animationRotate`,
`cavaVisualizer`, `clipboardPlus`, `cpuThermalIndicator`, `dankKDEConnect`,
`dankMenu`, `dankscale`, `desktopCommand`, `displayModes`, `enderPulse`,
`networkIndicator`, **`niriWindows`**, **`niriWorkspaceBar`**, `storageMonitor`.

- The DMS plugin registry (411 plugins at time of writing) has **no
  Hyprland-specific** plugins; the two `niri*` plugins are the only
  compositor-specific ones installed.
- Under Hyprland, the DMS core still draws the bar and dock. The workspace/window
  list may come from the generic DMS core rather than the niri plugins.
- If the niri plugins log errors or show nothing under Hyprland, disable them:

```bash
dms ipc call plugins disable niriWorkspaceBar
dms ipc call plugins disable niriWindows
dms ipc call plugins reload
```

- To re-enable: `dms ipc call plugins enable <id>`.

## 5. Window rules

DMS's own windows are layer-shell surfaces (bar, dock, menus), so Hyprland does
not tile them; the `rules.conf` entries for `dev.duxlabs.shell` /
`com.danklinux.dms` mostly ensure they float and stay opaque. Regular
XWayland/native apps (calculator, blueman, portal, PiP) get explicit
`windowrule {}` entries in `~/.config/hypr/rules.conf`.

## 6. Screenshots under Hyprland

The `niri` IPC target (`dms ipc call niri screenshot ...`) is niri-only. Under
Hyprland, verify which of these works:

```bash
dms screenshot              # region
dms screenshot window
dms screenshot full
dms ipc call screenshot begin   # low-level surface capture
```

If `dms screenshot` is a no-op under Hyprland, fall back to `grim` + `slurp`
(region) / `grim` (full) and bind those in `binds.conf`.

## 7. Verification checklist (first Hyprland login)

- [ ] Session starts; DMS bar and dock render.
- [ ] `Mod+Space` opens the menu; `Mod+Z` opens the launcher.
- [ ] `Mod+O` / `Mod+Tab` opens the overview.
- [ ] `Mod+Y` opens the keybinds overlay (Hyprland page).
- [ ] `Mod+Alt+L` locks; unlock works.
- [ ] Notifications appear; `Mod+Ctrl+N` opens the notification center.
- [ ] Audio/brightness OSDs respond to the function row.
- [ ] No errors from `niriWorkspaceBar` / `niriWindows` in the journal.
- [ ] Screenshots work (or the fallback is bound).
- [ ] niri session still boots as fallback.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| DMS does not start | service not pulled in | check `systemctl --user status dms.service`; it is `PartOf=graphical-session.target` |
| Bar/dock missing | DMS crashed on a stale config | `journalctl --user -u dms.service -b`; restart the service |
| niri plugins spam errors | they are niri-only | disable them (§4) |
| Screenshots do nothing | niri-only IPC target | use `grim`/`slurp` fallback |
| Keybinds overlay shows the niri page | stale path | `dms ipc call keybinds toggle hypr` |
| Layout looks wrong | colors/radii not synced from DMS theme | copy the DMS theme values into `hyprland.conf` |

## 9. Rollback

Log out and pick niri in ly — DMS starts there exactly as before. Nothing in the
DMS config is changed by the Hyprland migration. See `ROLLBACK-AND-SAFETY.md`.
