#!/usr/bin/env python3
"""Generate the Lua bind block for air's Hyprland config from live hyprctl binds.

Usage:
    hyprctl binds -j | ./scripts/12-gen-lua-binds.py > binds.lua
    ./scripts/12-gen-lua-binds.py binds.json > binds.lua

The emitted block is the keybinding section of configs/hypr/hyprland.lua.
Regenerate it after changing the keymap; do not hand-edit the generated block.
"""
import json, sys

if len(sys.argv) > 1:
    BINDS = json.load(open(sys.argv[1]))
else:
    BINDS = json.load(sys.stdin)

MOD_ORDER = [(64, "SUPER"), (1, "SHIFT"), (4, "CTRL"), (8, "ALT")]

def mods_str(modmask):
    parts = [name for bit, name in MOD_ORDER if modmask & bit]
    return " + ".join(parts)

def key_str(modmask, key):
    mods = mods_str(modmask)
    return f"{mods} + {key}" if mods else key

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

DIR = {"l": "left", "r": "right", "u": "up", "d": "down"}

def num_or_str(v):
    return v if v.isdigit() else lua_str(v)

def resize_closure(arg):
    # arg like "-4% 0" / "0 4%" / "4% 0" / "0 -4%"
    xs, ys = arg.split()
    def pct(tok):
        if tok.endswith("%"):
            return int(tok[:-1])
        return None
    xp, yp = pct(xs), pct(ys)
    xexpr = f"math.floor(w.size.x * {xp} / 100)" if xp is not None else xs
    yexpr = f"math.floor(w.size.y * {yp} / 100)" if yp is not None else ys
    return ("function() local w = hl.get_active_window(); if not w then return end; "
            f"hl.dispatch(hl.dsp.window.resize({{ x = {xexpr}, y = {yexpr}, relative = true }})) end")

def dispatcher_expr(b):
    d, a = b["dispatcher"], b["arg"]
    if d == "exec":
        return f"hl.dsp.exec_cmd({lua_str(a)})"
    if d == "exit":
        return "hl.dsp.exit()"
    if d == "killactive":
        return "hl.dsp.window.close()"
    if d == "pseudo":
        return "hl.dsp.window.pseudo()"
    if d == "layoutmsg":
        return f"hl.dsp.layout({lua_str(a.rstrip(','))})"
    if d == "fullscreen":
        return 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'
    if d == "movefocus":
        return f"hl.dsp.focus({{ direction = {lua_str(DIR.get(a, a))} }})"
    if d == "focusmonitor":
        return f"hl.dsp.focus({{ monitor = {lua_str(a)} }})"
    if d == "workspace":
        return f"hl.dsp.focus({{ workspace = {num_or_str(a)} }})"
    if d == "movetoworkspace":
        return f"hl.dsp.window.move({{ workspace = {num_or_str(a)} }})"
    if d == "movetoworkspacesilent":
        return f"hl.dsp.window.move({{ workspace = {lua_str(a)}, follow = false }})"
    if d == "togglespecialworkspace":
        return f"hl.dsp.workspace.toggle_special({lua_str(a)})"
    if d == "movewindow":
        if a.startswith("mon:"):
            return f"hl.dsp.window.move({{ monitor = {lua_str(a.split(':',1)[1])} }})"
        return f"hl.dsp.window.move({{ direction = {lua_str(DIR.get(a, a))} }})"
    if d == "swapwindow":
        return f"hl.dsp.window.swap({{ direction = {lua_str(DIR.get(a, a))} }})"
    if d == "cyclenext":
        return "hl.dsp.window.cycle_next({ next = false })" if a == "prev" else "hl.dsp.window.cycle_next()"
    if d == "resizeactive":
        return resize_closure(a)
    if d == "submap":
        return f"hl.dsp.submap({lua_str(a)})"
    if d == "mouse":
        if a == "movewindow":
            return "hl.dsp.window.drag()"
        if a == "resizewindow":
            return "hl.dsp.window.resize()"
        raise SystemExit(f"unknown mouse dispatcher {a}")
    raise SystemExit(f"unmapped dispatcher {d!r} arg {a!r}")

def opts_str(b):
    opts = []
    if b.get("repeat"):
        opts.append("repeating = true")
    if b.get("locked"):
        opts.append("locked = true")
    if b.get("mouse"):
        opts.append("mouse = true")
    if b.get("release"):
        opts.append("release = true")
    return "{ " + ", ".join(opts) + " }" if opts else ""

def emit(b, indent="    "):
    key = key_str(b["modmask"], b["key"])
    expr = dispatcher_expr(b)
    opts = opts_str(b)
    if opts:
        return f"{indent}hl.bind({lua_str(key)}, {expr}, {opts})"
    return f"{indent}hl.bind({lua_str(key)}, {expr})"

main, submap = [], []
for b in BINDS:
    if b["submap"] == "resize":
        submap.append(b)
    else:
        main.append(b)

out = []
out.append("-- ============================ Keybindings ============================")
out.append("-- Generated from the live hyprlang keymap; do not edit by hand.")
out.append("")
for b in main:
    out.append(emit(b))
out.append("")
out.append("-- ============================ Resize submap ============================")
out.append('hl.define_submap("resize", function()')
for b in submap:
    out.append(emit(b, indent="    "))
out.append("end)")
out.append("")
print("\n".join(out))
print(f"-- main binds: {len(main)}  submap binds: {len(submap)}  total: {len(main)+len(submap)}", file=sys.stderr)
