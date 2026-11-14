# Lua config port — evidence, mapping, and the gate

Why `~/.config/hypr/hyprland.lua` does not exist yet, and exactly what it takes
to add it. Written 2026-11-14 after measuring, not from the docs.

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
| `focusmonitor, l` | `hl.dsp.focus({ monitor = "l" })` | **unverified** — selector shape unknown |
| `swapwindow, l` | `hl.dsp.window.swap({ direction = "left" })` | documented |
| `movewindow, mon:l` | `hl.dsp.window.move({ monitor = "l" })` | **unverified** — `mon:` prefix has no documented Lua form |
| `resizeactive, -4% 0` | `hl.dsp.window.resize({ x = -4, y = 0, relative = true })` | **unverified** — the docs take numbers, hyprlang used percentages |
| `workspace, N` | `hl.dsp.focus({ workspace = N })` | certain (shipped example) |
| `workspace, e+1` | `hl.dsp.focus({ workspace = "e+1" })` | documented |
| `movetoworkspace, N` | `hl.dsp.window.move({ workspace = N })` | documented |
| `movetoworkspacesilent, special:x` | `hl.dsp.window.move({ workspace = "special:x", follow = false })` | documented |
| `togglespecialworkspace, x` | `hl.dsp.workspace.toggle_special("x")` | certain (shipped example) |
| `cyclenext` / `cyclenext, prev` | `hl.dsp.window.cycle_next()` / `({ next = false })` | first documented, second **unverified** |
| `submap, X` (+ `submap = reset`) | `hl.define_submap("X", "reset", fn)` and `hl.dsp.submap("X")` | defined in the stub, no worked example |
| `exit` | `hl.dsp.exit()` | certain |
| `bindm` mouse drag | `hl.bind(..., hl.dsp.window.drag(), { mouse = true })` | certain (shipped example) |
| `binde` repeat | `{ repeating = true }` | certain (`HL.BindOptions`) |

Four shapes are unverified — and they are precisely the ones that fail silently.

## The gate for the session that does this

1. Write `~/.config/hypr/hyprland.lua` covering **everything** the hyprlang
   files do (monitors, autostart, options, rules, binds). One file owns the
   config; two would reintroduce the drift this repo keeps fixing.
2. `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` → `config ok`.
3. Count binds statically: `hl.bind(` occurrences must equal the 139 the
   hyprlang profile registers today.
4. Keep `~/.config/hypr/hyprland.conf` **in place** — if the Lua file parses but
   behaves wrong, `rm hyprland.lua && hyprctl reload` returns the old keymap.
5. After switching, `hyprctl binds -j | grep -c dispatcher` must be ≥ 139, and
   every unverified row above must be exercised by hand, one key at a time.
6. Only then delete `hyprland.conf` / the hyprlang files from the repo.

Do it as its own task. It is a ~350-line rewrite of a working keymap with no
runtime validation available before the switch.

## What is true until then

- `./install.sh binds niri|omarchy` is the keybind interface.
- `SUPER+Y` shows DMS's *keybind* overlay (a static list), not the parsed
  cheatsheet. `dms keybinds show hyprland` fails.
- Everything else in the Omarchy contract layer works; see `docs/CONTRACT.md`.
