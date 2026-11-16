# Lua config port — evidence, mapping, and the gate

Why `~/.config/hypr/hyprland.lua` does not exist yet, and exactly what it takes
to add it. Written 2026-11-14 after measuring, not from the docs.

**Status: done 2026-11-16.** `configs/hypr/hyprland.lua` is the active session
config (Hyprland prefers Lua at startup; the provider is chosen once at startup,
so `hyprctl reload` does not switch). The hyprlang `.conf` set is kept as a
fallback and for `install.sh binds`. Regenerate the bind block after a keymap
change with `hyprctl binds -j | ./scripts/12-gen-lua-binds.py`.

## Why the port exists at all

DMS's `hyprland` provider parses **`~/.config/hypr/hyprland.lua`** and nothing
else:

```
$ dms keybinds show hyprland
FATAL Error getting cheatsheet: failed to parse hyprland config:
      stat /home/gio/.config/hypr/hyprland.lua: no such file or directory
```

So today the keybind cheatsheet (`SUPER+Y`) and `dms keybinds set hyprland …`
cannot work, no matter how good the hyprlang config is. `dms keybinds list`
offers `hyprland, mangowc, scroll, miracle, sway, niri` — there is no hyprlang
provider to switch to.

## What was measured (2026-11-14, Hyprland 0.55.2)

| Fact | Evidence |
|---|---|
| the session runs hyprlang | `hyprctl systeminfo` → `configProvider: hyprlang` |
| a Lua file *is* statically checkable | `Hyprland --verify-config -c file.lua` → `Config is lua, loading lua mgr`, `config ok` |
| Lua dispatchers do **not** exist at runtime in a hyprlang session | `hyprctl dispatch 'hl.dsp.focus({monitor="l"})'` → `Invalid dispatcher` for all ten tested, including `hl.dsp.layout("togglesplit")` |
| the API is shipped locally | `/usr/share/hypr/hyprland.lua` (example), `/usr/share/hypr/stubs/hl.meta.lua` (1250-line stub) |

The third row is the reason this is not done: **a dispatcher call cannot be
exercised until after the switch.** The only pre-switch gate is
`--verify-config`, which validates Lua syntax and `hl.config{}` shapes but not
dispatcher arguments (dispatchers are lazy tables, validated at dispatch time).
A wrong parameter therefore produces a key that does nothing, silently — the
same failure mode that emptied the keymap this morning.

## The mapping, for the 18 dispatchers actually in use

Source: `https://wiki.hypr.land/configuring/core/dispatchers/` (page modified
2026-11-13, same 0.55 line as the installed binary).

| hyprlang | Lua | confidence |
|---|---|---|
| `exec, CMD` | `hl.dsp.exec_cmd("CMD")` | certain (in the shipped example) |
| `killactive` | `hl.dsp.window.close()` | certain |
| `togglefloating` | `hl.dsp.window.float({ action = "toggle" })` | certain |
| `pseudo` | `hl.dsp.window.pseudo()` | certain |
| `pin` | `hl.dsp.window.pin()` | certain |
| `layoutmsg, togglesplit` | `hl.dsp.layout("togglesplit")` | certain (shipped example) |
| `togglegroup` | `hl.dsp.group.toggle()` | listed in the stub, method not in the table |
| `fullscreen, 1` | `hl.dsp.window.fullscreen({ mode = "maximized" })` | documented |
| `movefocus, l` | `hl.dsp.focus({ direction = "left" })` | certain (shipped example) |
| `focusmonitor, l` | `hl.dsp.focus({ monitor = "l" })` | verified 2026-11-16 (shape accepted; no second monitor to resolve) |
| `swapwindow, l` | `hl.dsp.window.swap({ direction = "left" })` | documented |
| `movewindow, mon:l` | `hl.dsp.window.move({ monitor = "l" })` | verified 2026-11-16 (shape accepted; no second monitor to resolve) |
| `resizeactive, -4% 0` | percent closure → `hl.dsp.window.resize({ x = math.floor(w.size.x * -4 / 100), y = 0, relative = true })` | verified 2026-11-16 (numbers only; percent strings rejected) |
| `workspace, N` | `hl.dsp.focus({ workspace = N })` | certain (shipped example) |
| `workspace, e+1` | `hl.dsp.focus({ workspace = "e+1" })` | documented |
| `movetoworkspace, N` | `hl.dsp.window.move({ workspace = N })` | documented |
| `movetoworkspacesilent, special:x` | `hl.dsp.window.move({ workspace = "special:x", follow = false })` | documented |
| `togglespecialworkspace, x` | `hl.dsp.workspace.toggle_special("x")` | certain (shipped example) |
| `cyclenext` / `cyclenext, prev` | `hl.dsp.window.cycle_next()` / `({ next = false })` | verified 2026-11-16 |
| `submap, X` (+ `submap = reset`) | `hl.define_submap("X", function() ... end)` and `hl.dsp.submap("X")` / `hl.dsp.submap("reset")` | verified 2026-11-16 |
| `exit` | `hl.dsp.exit()` | certain |
| `bindm` mouse drag | `hl.bind(..., hl.dsp.window.drag(), { mouse = true })` | certain (shipped example) |
| `binde` repeat | `{ repeating = true }` | certain (`HL.BindOptions`) |

All four formerly unverified shapes were exercised in a nested Lua session on
2026-11-16; see the gate below.

## Gate (executed 2026-11-16)

1. `configs/hypr/hyprland.lua` written, covering monitors, autostart, options,
   rules and all 141 binds (130 global + 11 resize-submap).
2. `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` → `config ok`.
3. `hl.bind(` count = 141, matching the live hyprlang keymap.
4. Nested Lua session: `configProvider: lua`, 141 binds registered. Dispatchers
   exercised: focus/workspace/movetoworkspace/togglespecial/cycle_next/submap/
   layout/fullscreen/pseudo/swap/resize/exec all `ok`. Monitor-direction binds
   return "monitor not found" on a one-monitor session (expected; same as hyprlang).
5. Live session left on hyprlang: the provider is chosen at startup, so activation
   is a logout/login. Rollback: `rm ~/.config/hypr/hyprland.lua` before the next
   start, or restore `~/.config/hypr/pre-lua-backup/`.
6. The hyprlang `.conf` set is kept as a fallback and for `install.sh binds`.

## Current state

- `configs/hypr/hyprland.lua` is the active config; `install.sh install --profile feel`
  deploys it (`scripts/02-hyprland-config.sh`) and validates it.
- `dms keybinds show hyprland` works once the session runs the Lua config.
- `./install.sh binds niri|omarchy` still switches the hyprlang fallback profiles;
  it does not edit the Lua keymap. Regenerate the Lua bind block after a keymap
  change with `scripts/12-gen-lua-binds.py`.
- Everything else in the Omarchy contract layer works; see `docs/CONTRACT.md`.
