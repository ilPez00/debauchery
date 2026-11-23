-- hyprland.lua — air (Debian 13 + DMS + debauchery)
-- Single source of truth for the Hyprland session. Ported from the hyprlang
-- config set (hyprland.conf + monitors/autostart/binds/rules/extra) so DMS's
-- keybind editor (`dms keybinds show hyprland`) can parse it.
-- Repo copy: ~/debauchery/configs/hypr/hyprland.lua

---------------- MONITORS ----------------
hl.monitor({
    output   = "eDP-1",
    mode     = "1440x900@60",
    position = "0x0",
    scale    = "1",
})
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------- ENV ----------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

---------------- AUTOSTART ----------------
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.service")
    hl.exec_cmd("/home/gio/.local/bin/physis-selector")
    hl.exec_cmd("systemctl --user start physis-omarchy.service")
end)

---------------- CONFIG ----------------
hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(42a5f5ff)", "rgba(42a5f5ff)" }, angle = 45 },
            inactive_border = "rgba(8c9199aa)",
        },
        layout = "dwindle",
        allow_tearing = false,
    },
    decoration = {
        rounding = 16,
        blur = { enabled = true, size = 6, passes = 2 },
        shadow = { enabled = true, range = 12 },
        active_opacity = 1.0,
        inactive_opacity = 0.95,
    },
    animations = { enabled = true },
    input = {
        kb_layout = "it",
        repeat_rate = 50,
        repeat_delay = 300,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
        sensitivity = 0.0,
    },
    misc = { force_default_wallpaper = 0 },
    dwindle = { preserve_split = true },
})

---------------- ANIMATIONS ----------------
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "myBezier" })

---------------- WINDOW RULES ----------------
hl.window_rule({
    name  = "dms-floating",
    match = { class = "^(dev\\.duxlabs\\.shell|com\\.danklinux\\.dms)$" },
    float = true,
    opacity = "1.0",
})

hl.window_rule({
    name  = "utilities-floating",
    match = { class = "^(org\\.gnome\\.Calculator|gnome-calculator|galculator|blueman-manager|xdg-desktop-portal)$" },
    float = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "^Picture-in-Picture$" },
    float = true,
    pin   = true,
})

-- ============================ Keybindings ============================
-- Generated from the live hyprlang keymap; do not edit by hand.

    hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
    hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
    hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
    hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
    hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))
    hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }))
    hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }))
    hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }))
    hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }))
    hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
    hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
    hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
    hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
    hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
    hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
    hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
    hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
    hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
    hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind("SUPER + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))
    hl.bind("SUPER + CTRL + Tab", hl.dsp.focus({ workspace = "previous" }))
    hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"))
    hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
    hl.bind("SUPER + grave", hl.dsp.workspace.toggle_special("qconsole"))
    hl.bind("SUPER + SHIFT + grave", hl.dsp.window.move({ workspace = "special:qconsole", follow = false }))
    hl.bind("SUPER + Q", hl.dsp.window.close())
    hl.bind("SUPER + W", hl.dsp.window.close())
    hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("omarchy-window-close-all"))
    hl.bind("SUPER + T", hl.dsp.exec_cmd("alacritty -e omarchy-arch"))
    hl.bind("SUPER + P", hl.dsp.window.pseudo())
    hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
    hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    hl.bind("SUPER + O", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
    hl.bind("SUPER + L", hl.dsp.exec_cmd("omarchy-layout-toggle"))
    hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
    hl.bind("SHIFT + ALT + Tab", hl.dsp.window.cycle_next({ next = false }))
    hl.bind("SUPER + Left", hl.dsp.focus({ direction = "left" }))
    hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }))
    hl.bind("SUPER + Up", hl.dsp.focus({ direction = "up" }))
    hl.bind("SUPER + Down", hl.dsp.focus({ direction = "down" }))
    hl.bind("SUPER + SHIFT + Left", hl.dsp.window.swap({ direction = "left" }))
    hl.bind("SUPER + SHIFT + Right", hl.dsp.window.swap({ direction = "right" }))
    hl.bind("SUPER + SHIFT + Up", hl.dsp.window.swap({ direction = "up" }))
    hl.bind("SUPER + SHIFT + Down", hl.dsp.window.swap({ direction = "down" }))
    hl.bind("SUPER + SHIFT + CTRL + Left", hl.dsp.window.move({ monitor = "l" }))
    hl.bind("SUPER + SHIFT + CTRL + Right", hl.dsp.window.move({ monitor = "r" }))
    hl.bind("SUPER + SHIFT + CTRL + Up", hl.dsp.window.move({ monitor = "u" }))
    hl.bind("SUPER + SHIFT + CTRL + Down", hl.dsp.window.move({ monitor = "d" }))
    hl.bind("SUPER + CTRL + Left", hl.dsp.focus({ monitor = "l" }))
    hl.bind("SUPER + CTRL + Right", hl.dsp.focus({ monitor = "r" }))
    hl.bind("SUPER + R", hl.dsp.exec_cmd("alacritty --class debian --title Debian"))
    hl.bind("SUPER + SHIFT + R", hl.dsp.submap("resize"))
    hl.bind("SUPER + Space", hl.dsp.exec_cmd("omarchy-menu"))
    hl.bind("SUPER + Escape", hl.dsp.exec_cmd("omarchy-menu-power"))
    hl.bind("SUPER + K", hl.dsp.exec_cmd("omarchy-menu-keybindings"))
    hl.bind("SUPER + Y", hl.dsp.exec_cmd("dms ipc call keybinds toggle hypr"))
    hl.bind("SUPER + A", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
    hl.bind("SUPER + X", hl.dsp.exec_cmd("omarchy-menu-power"))
    hl.bind("SUPER + D", hl.dsp.exec_cmd("dms-dash-toggle"))
    hl.bind("SUPER + Z", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
    hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
    hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notepad toggleExpand"))
    hl.bind("SUPER + V", hl.dsp.exec_cmd("omarchy-menu-clipboard"))
    hl.bind("SUPER + Comma", hl.dsp.exec_cmd("omarchy-notifications-toggle"))
    hl.bind("SUPER + CTRL + Comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
    hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("dms ipc call color-picker toggle"))
    hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("dms ipc call window-rules toggle"))
    hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd("dms ipc call inhibit toggle"))
    hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
    hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("dms ipc call night toggle"))
    hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("dms ipc call workspace-rename open"))
    hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("dms ipc call outputs cycleProfile"))
    hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
    hl.bind("Print", hl.dsp.exec_cmd("omarchy-capture-screenshot"))
    hl.bind("SUPER + Print", hl.dsp.exec_cmd("dms ipc call color-picker toggle"))
    hl.bind("SUPER + CTRL + Print", hl.dsp.exec_cmd("omarchy-capture-text"))
    hl.bind("ALT + Print", hl.dsp.exec_cmd("omarchy-capture-screenrecording"))
    hl.bind("SUPER + Backslash", hl.dsp.exec_cmd("dms screenshot window"))
    hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))
    hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd("firefox"))
    hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("firefox"))
    hl.bind("SUPER + E", hl.dsp.exec_cmd("firefox"))
    hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("thunar"))
    hl.bind("SUPER + B", hl.dsp.exec_cmd("thunar"))
    hl.bind("CTRL + ALT + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
    hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
    hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
    hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind("F1", hl.dsp.exec_cmd("omarchy-brightness-display -5%"), { repeating = true })
    hl.bind("F2", hl.dsp.exec_cmd("omarchy-brightness-display +5%"), { repeating = true })
    hl.bind("F3", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
    hl.bind("F4", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
    hl.bind("F5", hl.dsp.exec_cmd("omarchy-brightness-keyboard down"), { repeating = true })
    hl.bind("F6", hl.dsp.exec_cmd("omarchy-brightness-keyboard up"), { repeating = true })
    hl.bind("F7", hl.dsp.exec_cmd("omarchy-media previous"))
    hl.bind("F8", hl.dsp.exec_cmd("omarchy-media play-pause"))
    hl.bind("F9", hl.dsp.exec_cmd("omarchy-media next"))
    hl.bind("F10", hl.dsp.exec_cmd("dms ipc call audio mute"))
    hl.bind("F11", hl.dsp.exec_cmd("omarchy-audio-output-volume -3"), { repeating = true })
    hl.bind("F12", hl.dsp.exec_cmd("omarchy-audio-output-volume +3"), { repeating = true })
    hl.bind("XF86PowerOff", hl.dsp.exec_cmd("omarchy-menu-power"))
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("omarchy-brightness-display -5%"), { repeating = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("omarchy-brightness-display +5%"), { repeating = true })
    hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness set 1%"))
    hl.bind("SHIFT + XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness set 100%"))
    hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd("omarchy-brightness-display -1%"))
    hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd("omarchy-brightness-display +1%"))
    hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("omarchy-brightness-keyboard down"), { repeating = true })
    hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("omarchy-brightness-keyboard up"), { repeating = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("omarchy-media previous"))
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("omarchy-media play-pause"))
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("omarchy-media play-pause"))
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("omarchy-media next"))
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"))
    hl.bind("SHIFT + XF86AudioMute", hl.dsp.exec_cmd("omarchy-audio-output-switch"))
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("omarchy-audio-input-mute"))
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume -3"), { repeating = true })
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume +3"), { repeating = true })
    hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume -1"))
    hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("omarchy-audio-output-volume +1"))
    hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd("omarchy-toggle-touchpad"))
    hl.bind("XF86TouchpadOn", hl.dsp.exec_cmd("omarchy-toggle-touchpad on"))
    hl.bind("XF86TouchpadOff", hl.dsp.exec_cmd("omarchy-toggle-touchpad off"))
    hl.bind("SUPER + M", hl.dsp.exec_cmd("alacritty --class rice -e omarchy-rice"))
    hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("physis-omarchy inspect --in-terminal"))
    hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("physis-omarchy hud"))
    hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("physis-omarchy fuzzel"))

-- ============================ Resize submap ============================
hl.define_submap("resize", function()
    hl.bind("H", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * -4 / 100), y = 0, relative = true })) end, { repeating = true })
    hl.bind("L", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * 4 / 100), y = 0, relative = true })) end, { repeating = true })
    hl.bind("J", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = 0, y = math.floor(w.size.y * 4 / 100), relative = true })) end, { repeating = true })
    hl.bind("K", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = 0, y = math.floor(w.size.y * -4 / 100), relative = true })) end, { repeating = true })
    hl.bind("Left", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * -4 / 100), y = 0, relative = true })) end, { repeating = true })
    hl.bind("Right", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * 4 / 100), y = 0, relative = true })) end, { repeating = true })
    hl.bind("Down", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = 0, y = math.floor(w.size.y * 4 / 100), relative = true })) end, { repeating = true })
    hl.bind("Up", function() local w = hl.get_active_window(); if not w then return end; hl.dispatch(hl.dsp.window.resize({ x = 0, y = math.floor(w.size.y * -4 / 100), relative = true })) end, { repeating = true })
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Space", hl.dsp.submap("reset"))
end)

