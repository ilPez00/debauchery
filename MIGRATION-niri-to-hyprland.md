# Migration Plan — niri → Hyprland (air)

> Companion to `PLAN.md`. This document plans the **desktop migration** from
> niri to Hyprland while preserving DMS as the shell layer, and translating
> behaviors/hotkeys into **Hyprland idioms** (not a niri emulation).
>
> **Status:** plan written; nothing applied. See §8 for phases and §13 (PLAN.md)
> for the verification log.

---

## 1. Goals and non-goals

### Goals

1. Make Hyprland a real, working session on air with the **Hyprland feel**:
   dwindle/master layouts, Hyprland animations, groups, workspace rules.
2. Preserve the **DMS shell** (bar, launcher, menus, notifications, OSDs,
   control center, lock, wallpaper) — DMS is compositor-agnostic and has a
   native `hypr` IPC target.
3. Translate the existing niri + DMS behaviors and hotkeys to Hyprland
   equivalents, keeping the same *modifiers and muscle memory* where possible.
4. Keep niri installed and one logout away as a **fallback** until Hyprland is
   verified.
5. Keep the Arch Distrobox and Physis out of the critical path.

### Non-goals

- Not cloning niri's scrollable-column model into Hyprland (that would fight
  the compositor; use Hyprland's own layout instead).
- Not installing the upstream Omarchy Quickshell shell in the same session as
  DMS (two shells conflict). If the Omarchy shell is wanted, it gets its own
  session.
- Not touching the kernel, bootloader, or Debian packaging.

---

## 2. Key discovery — DMS is already Hyprland-aware

DMS exposes an explicit `hypr` IPC target (verified via `dms ipc --help`):

```
hypr   closeBinds, closeOverview, openBinds, openOverview, toggleBinds, toggleOverview
niri   screenshot, screenshotScreen, screenshotWindow, showTouchpadOsd
```

Consequences:

- The **overview** (niri `toggle-overview`) maps to `dms ipc call hypr toggleOverview`.
- The **keybinds overlay** maps to `dms ipc call keybinds toggle hypr` (path changes
  from `niri` to `hypr`).
- DMS's bar/dock/launcher/notification surfaces are layer-shell based and work
  under Hyprland.
- DMS plugins `niriWindows` / `niriWorkspaceBar` are niri-specific; under
  Hyprland they must be replaced by Hyprland-aware equivalents (DMS registry or
  the `hypr` IPC target).

---

## 3. Behavioral model mapping

| niri behavior | Hyprland equivalent | Notes |
|---|---|---|
| Scrollable tiling, one column per workspace, horizontal scroll | **dwindle** (default) or **master** | Use Hyprland's model. Recommended: `dwindle` for a natural Hyprland feel; `master` if you want a fixed left column. |
| Workspace 1–9, linear, `e+1`/`e-1` relative | same (`workspace, N` / `workspace, e+1`) | native |
| Column width presets 1/3, 1/2, 2/3 | master `mfact` / `resizeactive` | approximate; see §4 |
| Focus window up/down/left/right | `movefocus, u/d/l/r` | native |
| Move window up/down/left/right | `movewindow, u/d/l/r` | native; also moves across workspaces |
| Focus column left/right | `movefocus, l/r` | native |
| Move column left/right | `movewindow, l/r` | approximate |
| Consume/expel window left/right | `togglegroup` / `movewindow, l/r` | no exact equivalent |
| Tabbed column display | **groups** (`togglegroup`) | Hyprland groups are the idiomatic tabbed container |
| Floating window | `togglefloating` | native |
| Switch focus floating/tiling | `focuswindow` (by class) or a small script | approximate |
| Maximize column | `fullscreen, 1` (maximize) | native |
| Fullscreen window | `fullscreen, 0` | native |
| Center column | `resizeactive` / `movewindow` | no exact equivalent |
| Expel window from column | `togglefloating` | approximate |
| Overview | `dms ipc call hypr toggleOverview` | DMS provides it |
| Focus monitor | `focusmonitor, l/r/u/d` | native |
| Move window to monitor | `movewindow, mon:l/r/u/d` | native |
| Move column/window to workspace | `movetoworkspace, N` / `e+1` / `e-1` | native |
| Move workspace up/down | **no direct equivalent** | Hyprland workspaces are linear; drop or script |
| Scratchpad | `dms ipc call scratchpad toggle` | DMS provides it |
| Animations | `animations { ... }` (bezier) | Hyprland-native |
| Rounded corners / blur / shadow | `decoration { rounding, blur, shadow }` | from DMS theme colors |
| Gaps / borders | `general { gaps_in, gaps_out, border_size, col.* }` | from DMS theme |
| Window rules (floating apps, geometry) | `windowrulev2` | translate from DMS kdl |
| Touchpad tap/natural-scroll/dwt | `input { touchpad { ... } }` | native |
| Keyboard layout / repeat rate | `input { kb_layout, repeat_rate }` | native |
| Focus follows mouse | `general { focus_on_close }` / `input { follow_mouse }` | optional |

### Deliberately not ported

- **Scrollable columns** — replaced by Hyprland layouts.
- **Move workspace up/down** — no Hyprland equivalent.
- **Consume/expel, center-column, reset-window-height** — approximated or dropped.
- **`toggle-keyboard-shortcuts-inhibit`** — niri-specific; DMS has its own
  inhibit (`dms ipc call inhibit toggle`).

### Hyprland-native additions worth adopting

- **Groups** for tabbed workflows (`togglegroup`, `moveintogroup`, `moveoutofgroup`).
- **Scratchpad** via DMS (`dms ipc call scratchpad toggle`).
- **Workspace rules** for per-app floating/geometry/monitor placement.
- **Bezier animations** and per-workspace wallpaper (`wpaperd`, optional).
- **Hyprexpo**-style overview is not built in; DMS's `hypr toggleOverview` is the
  overview surface.

---

## 4. Hotkey mapping (niri + DMS → Hyprland)

Hyprland bind syntax: `bind = MODS, key, dispatcher, arg`. Use `bind` for
one-shot actions, `binde` where niri had repeat (hold). Empty modifier list is
written `bind = , KEY, ...`.

### 4.1 Workspaces

| niri/DMS | Hyprland |
|---|---|
| `Mod+1..9` focus workspace | `bind = SUPER, 1, workspace, 1` … `9` |
| `Mod+Shift+1..9` move window to workspace | `bind = SUPER SHIFT, 1, movetoworkspace, 1` … `9` |
| `Mod+I` / `Mod+U` focus workspace up/down | `bind = SUPER, I, workspace, e+1` / `bind = SUPER, U, workspace, e-1` |
| `Mod+Page_Up` / `Mod+Page_Down` | same as above |
| `Mod+WheelScrollUp/Down` | `bind = SUPER, mouse_up, workspace, e-1` / `bind = SUPER, mouse_down, workspace, e+1` |
| `Mod+Ctrl+I` / `Mod+Ctrl+Up` move to workspace up | `bind = SUPER CTRL, I, movetoworkspace, e+1` |
| `Mod+Ctrl+U` / `Mod+Ctrl+Down` | `bind = SUPER CTRL, U, movetoworkspace, e-1` |
| `Mod+Ctrl+WheelScrollUp/Down` | `bind = SUPER CTRL, mouse_up, movetoworkspace, e-1` / `mouse_down, e+1` |
| `Mod+Shift+I/U`, `Mod+Shift+Page_Up/Down` (move workspace) | **no equivalent** — drop |
| `Mod+Shift+WheelScrollLeft/Right` focus column | `bind = SUPER SHIFT, mouse_up, movefocus, l` / `mouse_down, r` |
| `Mod+WheelScrollLeft/Right` focus column | `bind = SUPER, mouse_up, movefocus, l` / `mouse_down, r` |
| `Mod+Ctrl+WheelScrollLeft/Right` move column | `bind = SUPER CTRL, mouse_up, movewindow, l` / `mouse_down, r` |

### 4.2 Focus and movement

| niri/DMS | Hyprland |
|---|---|
| `Mod+H/J/K/L`, `Mod+arrows` | `bind = SUPER, J, movefocus, d` (+ `u`, `l`, `r`) |
| `Mod+Shift+H/J/K/L`, `Mod+Shift+arrows` | `bind = SUPER SHIFT, J, movewindow, d` (+ `u`, `l`, `r`) |
| `Mod+Home` / `Mod+End` (column first/last) | approximate: `bind = SUPER, Home, movefocus, l` (hold) / `End, r` — verify |
| `Mod+Ctrl+H/J/K/L`, `Mod+Ctrl+arrows` focus monitor | `bind = SUPER CTRL, H, focusmonitor, l` (+ `r`, `u`, `d`) |
| `Mod+Shift+Ctrl+H/J/K/L` move to monitor | `bind = SUPER SHIFT CTRL, H, movewindow, mon:l` (+ `mon:r/u/d`) |
| `Mod+Shift+V` focus floating/tiling | approximate: `bind = SUPER SHIFT, V, focuswindow, class:` — verify |
| `Mod+Period` expel from column | `bind = SUPER, PERIOD, togglefloating,` |
| `Mod+BracketLeft/Right` consume/expel | `bind = SUPER, BRACKETLEFT, movewindow, l` / `BRACKETRIGHT, r` |
| `Mod+C` center column | approximate: `bind = SUPER, C, resizeactive, 0 0` — verify |
| `Mod+Ctrl+C` center visible columns | **no equivalent** — drop |

### 4.3 Layout

| niri/DMS | Hyprland |
|---|---|
| `Mod+R` cycle column width | approximate: `bind = SUPER, R, layoutmsg, mfact 0.5` (master) or `resizeactive` — verify |
| `Mod+Equal` / `Mod+Minus` column width ±10% | `bind = SUPER, EQUAL, resizeactive, 10% 0` / `MINUS, resizeactive, -10% 0` |
| `Mod+Shift+Equal` / `Mod+Shift+Minus` window height | `bind = SUPER SHIFT, EQUAL, resizeactive, 0 10%` / `MINUS, 0 -10%` |
| `Mod+Ctrl+F` expand to available width | `bind = SUPER CTRL, F, fullscreen, 1` |
| `Mod+F` maximize | `bind = SUPER, F, fullscreen, 1` |
| `Mod+Shift+F` fullscreen | `bind = SUPER SHIFT, F, fullscreen, 0` |
| `Mod+Shift+T` toggle floating | `bind = SUPER SHIFT, T, togglefloating,` |
| `Mod+W` tabbed display | `bind = SUPER, W, togglegroup,` |
| `Mod+Ctrl+R` reset window height | approximate: `bind = SUPER CTRL, R, resizeactive, 0 0` — verify |
| `Mod+Shift+R` cycle window height | **no equivalent** — drop |
| `Mod+Q` close window | `bind = SUPER, Q, killactive,` |
| `Mod+Shift+P` power off monitors | `bind = SUPER SHIFT, P, exec, dms ipc call outputs toggleAuto` — verify |
| `Mod+Shift+E` quit compositor | `bind = SUPER SHIFT, E, exit,` |

### 4.4 DMS shell binds (keep the same modifiers)

| niri/DMS | Hyprland (`exec`) |
|---|---|
| `Mod+Space` dankMenu | `bind = SUPER, SPACE, exec, dms ipc call dankMenu toggle root` |
| `Mod+Tab` / `Mod+O` overview | `bind = SUPER, TAB, exec, dms ipc call hypr toggleOverview` (+ `O`) |
| `Mod+A` control center | `bind = SUPER, A, exec, dms ipc call control-center toggle` |
| `Mod+D` dash | `bind = SUPER, D, exec, dms ipc call dash toggle ""` |
| `Mod+Z` spotlight | `bind = SUPER, Z, exec, dms ipc call spotlight toggle` |
| `Mod+V` clipboard | `bind = SUPER, V, exec, dms ipc call clipboard toggle` |
| `Mod+N` / `Mod+Shift+N` notepad | `bind = SUPER, N, exec, dms ipc call notepad toggle` / `SUPER SHIFT, N, ..., toggleExpand` |
| `Mod+X` power menu | `bind = SUPER, X, exec, dms ipc call powermenu toggle` |
| `Mod+Comma` settings | `bind = SUPER, COMMA, exec, dms ipc call settings focusOrToggle` |
| `Mod+Shift+W` window rules | `bind = SUPER SHIFT, W, exec, dms ipc call window-rules toggle` |
| `Mod+Shift+C` color picker | `bind = SUPER SHIFT, C, exec, dms ipc call color-picker toggle` |
| `Mod+Ctrl+N` notifications | `bind = SUPER CTRL, N, exec, dms ipc call notifications toggle` |
| `Mod+Alt+I` idle inhibit | `bind = SUPER ALT, I, exec, dms ipc call inhibit toggle` |
| `Mod+Alt+L` lock | `bind = SUPER ALT, L, exec, dms ipc call lock lock` |
| `Mod+Alt+N` night mode | `bind = SUPER ALT, N, exec, dms ipc call night toggle` |
| `Mod+Alt+R` rename workspace | `bind = SUPER ALT, R, exec, dms ipc call workspace-rename open` |
| `Mod+P` cycle display profile | `bind = SUPER, P, exec, dms ipc call outputs cycleProfile` |
| `Mod+Backslash` screenshot window | `bind = SUPER, BACKSLASH, exec, dms screenshot window` — verify under Hyprland |
| `Print` screenshot region | `bind = , PRINT, exec, dms screenshot` — verify |
| `Ctrl+Print` screenshot full | `bind = CTRL, PRINT, exec, dms screenshot full` — verify |
| `Ctrl+Alt+Delete` / `Ctrl+Alt+M` task manager | `bind = CTRL ALT, DELETE, exec, dms ipc call processlist focusOrToggle` (+ `M`) |
| `Alt+Space` spotlight bar | `bind = ALT, SPACE, exec, dms ipc call spotlight-bar toggle` |
| `Mod+Y` keybinds overlay | `bind = SUPER, Y, exec, dms ipc call keybinds toggle hypr` |
| `Mod+Return` / `Mod+T` terminal | `bind = SUPER, RETURN, exec, alacritty` / `T` |
| `Mod+E` / `Mod+B` browser / files | `bind = SUPER, E, exec, firefox` / `B, exec, thunar` |
| `Mod+Escape` shortcuts inhibit | niri-specific; use `dms ipc call inhibit toggle` — verify |

### 4.5 MacBook function row

Plain press emits F1–F12 (hid_apple `fnmode=2`); `Fn+key` emits the XF86 media
keysyms. Bind **both** so the row works either way:

```
# F1/F2 brightness
bind = , F1, exec, dms ipc call brightness decrement 5 ""
bind = , F2, exec, dms ipc call brightness increment 5 ""
# F3 overview / F4 launcher
bind = , F3, exec, dms ipc call hypr toggleOverview
bind = , F4, exec, dms ipc call spotlight toggle
# F5/F6 keyboard backlight
bind = , F5, exec, brightnessctl -d smc::kbd_backlight set 10%-
bind = , F6, exec, brightnessctl -d smc::kbd_backlight set 10%+
# F7/F8/F9 media
bind = , F7, exec, dms ipc call mpris previous
bind = , F8, exec, dms ipc call mpris playPause
bind = , F9, exec, dms ipc call mpris next
# F10/F11/F12 volume
bind = , F10, exec, dms ipc call audio mute
bind = , F11, exec, dms ipc call audio decrement 3
bind = , F12, exec, dms ipc call audio increment 3
# Fn+key (XF86 keysyms) — same actions
bind = , XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5 ""
bind = , XF86MonBrightnessUp,   exec, dms ipc call brightness increment 5 ""
bind = , XF86KbdBrightnessDown, exec, brightnessctl -d smc::kbd_backlight set 10%-
bind = , XF86KbdBrightnessUp,   exec, brightnessctl -d smc::kbd_backlight set 10%+
bind = , XF86AudioPrev,  exec, dms ipc call mpris previous
bind = , XF86AudioPlay,  exec, dms ipc call mpris playPause
bind = , XF86AudioPause, exec, dms ipc call mpris playPause
bind = , XF86AudioNext,  exec, dms ipc call mpris next
bind = , XF86AudioMute,  exec, dms ipc call audio mute
bind = , XF86AudioLowerVolume, exec, dms ipc call audio decrement 3
bind = , XF86AudioRaiseVolume, exec, dms ipc call audio increment 3
```

> Better: set `hid_apple fnmode=1` (media by default, `Fn+key` = real F1–F12).
> Then only the XF86 binds are needed and the function row behaves like macOS.
> This needs one polkit click (see PLAN.md §8 Phase 3/4).

---

## 5. Hyprland config skeleton (translated from niri + DMS)

```
# ~/.config/hypr/hyprland.conf
exec-once = dms run --session        # or rely on dms.service; verify
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/autostart.conf
source = ~/.config/hypr/binds.conf
source = ~/.config/hypr/rules.conf
source = ~/.config/hypr/extra.conf   # REQUIRED by the Physis adapter

general {
    gaps_in  = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(42a5f5ff) rgba(42a5f5ff) 45deg
    col.inactive_border = rgba(8c9199aa)
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 16
    blur { enabled = true size = 6 passes = 2 }
    shadow { enabled = true range = 12 softness = 8 }
    active_opacity = 1.0
    inactive_opacity = 0.95
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows,   1, 4, myBezier
    animation = workspaces,1, 4, myBezier, slide
    animation = fade,      1, 4, myBezier
}

input {
    kb_layout = us
    repeat_rate = 50
    repeat_delay = 300
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
    sensitivity = 0.0
}

gestures { workspace_swipe = false }

misc {
    disable_autoreload = false
    force_default_wallpaper = 0
}

# dwindle
dwindle { pseudotile = true preserve_split = true }

# master (optional alternative)
# master { mfact = 0.5 new_is_master = true }
```

Colors and radii come from the DMS theme (`~/.config/dms/settings.json` and the
`dms/*.kdl` includes). Keep them in sync manually or via the port kit.

### monitors.conf

```
monitor = eDP-1, 1440x900@60, 0x0, 1   # MacBook Air 2016 panel (verify with hyprctl monitors)
```

### rules.conf (translate from DMS window rules)

```
windowrulev2 = float, class:(^(dev\.duxlabs\.shell|com\.danklinux\.dms)$)
windowrulev2 = float, class:(^(org\.gnome\.Calculator|gnome-calculator|galculator|blueman-manager|xdg-desktop-portal)$)
windowrulev2 = tile, class:(^(dev\.duxlabs\.shell|com\.danklinux\.dms)$)
windowrulev2 = opacity 1.0, class:(^(dev\.duxlabs\.shell|com\.danklinux\.dms)$)
windowrulev2 = rounded corners off, class:(^(dev\.duxlabs\.shell|com\.danklinux\.dms)$)
```

---

## 6. DMS under Hyprland — what changes

| Item | niri | Hyprland |
|---|---|---|
| DMS process | user service `dms.service` | keep the same service; verify it follows the session |
| Workspace bar | plugin `niriWorkspaceBar` | replace with a Hyprland-aware bar widget (DMS registry) or the `hypr` IPC |
| Window list | plugin `niriWindows` | Hyprland-aware equivalent |
| Overview | niri `toggle-overview` | `dms ipc call hypr toggleOverview` |
| Keybinds overlay | `keybinds toggle niri` | `keybinds toggle hypr` |
| Screenshots | `dms screenshot ...` / `niri` target | verify DMS's Hyprland path (`dms screenshot`, or `screenshot` target) |
| Window rules | niri kdl includes | DMS settings + `rules.conf` |
| Compositor detection | `XDG_CURRENT_DESKTOP=niri` | set `XDG_CURRENT_DESKTOP=Hyprland` for the session |

---

## 7. Migration phases

### Phase A — Install Hyprland (additive; niri untouched)

```bash
sudo apt update
sudo apt install -t trixie-backports hyprland hyprlock hypridle hyprpaper \
  xdg-desktop-portal-hyprland uwsm
sudo apt install -y distrobox podman cargo rustc
```

Add a ly session entry `/usr/share/wayland-sessions/hyprland.desktop` with
`DesktopNames=Hyprland`. **Do not change the default session.**

Verify the session appears in ly and that niri still boots.

### Phase B — Config translation

1. Write `~/.config/hypr/{hyprland.conf,monitors.conf,autostart.conf,binds.conf,rules.conf,extra.conf}`.
2. Run `hyprctl` sanity checks from a TTY? (Hyprland config is validated on
   start; use `Hyprland` in a nested/VM or check logs.)
3. Ensure `~/.config/hypr/extra.conf` exists and is sourced (Physis adapter
   requirement).

### Phase C — First Hyprland login (verification)

1. Log out; choose Hyprland in ly.
2. Verify: DMS bar/dock, launcher (`Mod+Z`), menu (`Mod+Space`), overview
   (`Mod+O`), notifications, audio/brightness keys, function row, monitors,
   animations, lock (`Mod+Alt+L`).
3. Fix config issues; iterate.
4. Keep niri available as fallback.

### Phase D — Make Hyprland the default (only after Phase C passes)

Change ly's default session to Hyprland (or set it in ly's config), keeping
niri installed and selectable. Record the change in `notes/`.

### Phase E — Optional: Omarchy shell or Physis adapter

- If the Omarchy Quickshell shell is wanted, install the port kit in its own
  session (never alongside DMS).
- If the Physis adapter is wanted, install `cargo`, verify `extra.conf` is
  sourced, then `OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh`.

---

## 8. Rollback

- **To niri:** log out, pick niri in ly (or restore ly's default session).
  Nothing is uninstalled; niri config and DMS config are untouched.
- **To remove Hyprland:** `sudo apt remove hyprland hyprlock hypridle hyprpaper
  xdg-desktop-portal-hyprland uwsm`; delete `~/.config/hypr/`; remove the ly
  session file.
- **DMS config:** backed up in `~/debauchery/backups/`.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| DMS behaves differently under Hyprland (untested on air) | test in Phase C before changing the default; niri fallback |
| DMS niri-specific plugins (`niriWorkspaceBar`, `niriWindows`) are dead under Hyprland | swap for Hyprland-aware widgets or use the `hypr` IPC target |
| Overview/keybinds path change | use `dms ipc call hypr ...` / `keybinds toggle hypr` |
| Screenshot path differs under Hyprland | verify `dms screenshot` / `screenshot` target |
| Function-row keys differ by fnmode | bind both F1–F12 and XF86; consider `fnmode=1` |
| `movewindow, mon:` / `layoutmsg` syntax uncertainty | verify with `hyprctl` in the session; adjust |
| Hyprland animations/colors differ from DMS theme | sync colors manually; iterate |
| Port-kit system changes (if used) | review steps 65/72/73/74; keep niri fallback |

---

## 10. Verification checklist

- [ ] `hyprctl systeminfo` works in the Hyprland session.
- [ ] DMS bar/dock/launcher/menu/notifications render.
- [ ] `Mod+Space` menu, `Mod+Z` spotlight, `Mod+O` overview.
- [ ] `Mod+1..9` workspaces; `Mod+Shift+1..9` move windows.
- [ ] `Mod+HJKL` focus; `Mod+Shift+HJKL` move; floating toggle.
- [ ] Brightness/volume/media keys; F1–F12 function row.
- [ ] Monitors detected (`hyprctl monitors`); eDP-1 resolution/scale correct.
- [ ] Lock screen (`Mod+Alt+L`) works.
- [ ] niri session still boots as fallback.
- [ ] No DMS/niri plugin errors in the journal (`journalctl --user -b`).

---

## 11. Open decisions

1. Default layout: **dwindle** (recommended, most Hyprland) or **master**?
2. Set `hid_apple fnmode=1` (media by default) or keep `fnmode=2` and bind both?
3. Replace DMS niri plugins with Hyprland widgets, or keep DMS minimal under
   Hyprland?
4. Change the ly default to Hyprland immediately after Phase C, or stay manual?
5. Omarchy shell in a separate session later, or stay with DMS?
