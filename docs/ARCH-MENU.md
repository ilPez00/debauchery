# The arch menu (omarchy-rice) — and how everything around it toggles

ArcoLinux-style post-login menu for the Debian+DMS session: `omarchy-rice`
(alias `arch-menu`, **SUPER+M**). It is a whiptail loop that runs in a
terminal; every action also works headless, so binds and scripts do not need
the menu at all.

```
arch-menu                  # the menu (needs a terminal; SUPER+M opens one)
arch-menu --login          # autostart path: sleep 5, open menu unless disabled
arch-menu --install        # idempotent: SUPER+M bind + autostart line
arch-menu <action> [arg]   # headless — same actions the menu runs
```

## Actions (all headless-verified 2026-11-15)

| Command | What it does |
|---|---|
| `arch-menu shell [dms\|noctalia]` | switches the whole shell: stops one systemd user unit, starts the other (`dms.service` ↔ `noctalia.service`, both on `graphical-session.target`). No arg = toggle. Ask-confirmed in the menu. |
| `arch-menu menus <name>` | opens one of: `dankmenu`, `spotlight`, `launcher`, `powermenu`, `keybinds`, `notes` (DMS built-in notepad) |
| `arch-menu bar [toggle\|autohide\|status]` | wraps `omarchy-bar` |
| `arch-menu dock [toggle\|status]` | wraps `omarchy-dock` |
| `arch-menu theme dark\|light\|next\|<name>` | dark/light mode, next wallpaper, or a named theme from `omarchy theme list` |
| `arch-menu binds [niri\|omarchy]` | switch the keybind profile via `install.sh binds` (Hyprland-verified before it goes live) |
| `arch-menu login on\|off` | show the menu at login (default on; stored in `~/.config/debauchery/rice.conf` as `RICE_AT_LOGIN`) |

Menu items with sub-choices (shell, menus, bar, theme) open a second whiptail
picker. Esc at any level quits the menu.

## How the pieces work

- **Shell toggle**: `dms` and `noctalia` are two user services wired to
  `graphical-session.target`. The switch is exactly what the
  `niri-noctalia.desktop` session does (`systemctl --user disable --now <a>`,
  `enable --now <b>`). If a switch leaves you without a shell, SUPER+M still
  opens a terminal (alacritty runs without the shell), and `arch-menu shell dms`
  brings DMS back.
- **Login gate**: `exec-once = alacritty --class rice -e omarchy-rice --login`
  in `~/.config/hypr/autostart.conf`; `--login` waits 5 s (DMS up), then opens
  the menu unless `RICE_AT_LOGIN=0`.
- **Terminal**: alacritty (present); override with `RICE_TERMINAL=kitty`.
- `scripts/11-omarchy-shims.sh` deploys `omarchy-rice` and links
  `~/.local/bin/arch-menu -> omarchy-rice`.

## Known traps

- `dms ipc call bar <fn>` takes **two** args: a selector (`index|id|name`) and
  a value. `omarchy-bar` hides this; raw IPC calls return `BAR_INVALID_SELECTOR`
  otherwise.
- `dms ipc call dankMenu toggle` needs a route (`root`), `keybinds toggle`
  needs a provider (`hypr`) — both are baked into the menu.
- `powermenu toggle` answers with an empty body (build quirk), exit 0 — it works.
- `settings set` over IPC refuses arrays/objects by design, so bar widget
  lists are edited while dms is stopped (see the plugin section below).

---

# GUI plugins on the bar: GitHub Inbox + Mail Checker

Both are DankBar widget plugins installed with `omarchy-plugin-add <id>`
(install → dms restart → enable → `loaded`). **Enabling is not enough** — a
widget plugin only appears once its id is in the bar's widget list.

## How plugin widgets get on the bar

DMS keeps per-bar widget lists in `~/.config/dms/settings.json`:
`barConfigs[].leftWidgets / centerWidgets / rightWidgets`. A plugin widget is
an entry with the **plugin id** (variants would be `pluginId:variant_<ts>`):

```json
"rightWidgets": ["systemTray", "clipboard", "githubInbox", "mailChecker", ...]
```

`dms ipc call settings set` **refuses arrays** ("Setting Objects and Arrays not
supported"), so the supported path is the bar edit UI — or the scripted way
used here: stop dms, edit the JSON, start it (settings are only loaded at
startup):

```bash
systemctl --user stop dms.service
# edit barConfigs[0].{left,center,right}Widgets
systemctl --user start dms.service
```

Defaults (what an untouched bar renders, from DMS source):
left `launcherButton workspaceSwitcher focusedWindow` ·
center `music clock weather` ·
right `systemTray clipboard cpuUsage memUsage notificationButton battery
controlCenterButton`.

Current air bar: defaults + `githubInbox` + `mailChecker` in the right section.

## GitHub Inbox (PR / issue notices)

- Reads the GitHub notifications API — your open PRs, review requests, issues.
- Config: **a classic personal access token** (https://github.com/settings/tokens,
  scopes: `notifications` + `read:user`; add full `repo` for private repos).
  The plugin stores the token itself through the Secret Service — open its
  bar popout and click the gear/token button, paste the token. (Run
  `gh auth login` separately if you want the `gh` CLI authed too; the plugin
  does not use gh.)
- Deps present on air: curl, jq, file, and `secret-tool` (installed via
  `libsecret-tools`; gnome-keyring-daemon runs with `--components=secrets`).
- Keyring roundtrip proven: `secret-tool store/lookup/clear`.

## Mail Checker (unread mail)

IMAP poller (stdlib Python, read-only, `BODY.PEEK` — never marks mail read):
bar envelope with unread count, popout message list, desktop notifications.

Configured keys (`~/.config/dms/plugin_settings.json` → `mailChecker`):
`accountName`, `imapHost`, `imapPort`, `security` (ssl|starttls), `username`,
`folder` (INBOX), `pollInterval` (seconds, min 30), **`passwordCommand`** —
a shell command that prints the password (it is never stored in settings).

air preset: `passwordCommand: secret-tool lookup service imap account gio`.
Finish it with your real mailbox:

```bash
# 1. store the password once (keyring is already unlocked in this session)
secret-tool store --label='IMAP' service imap account gio
# 2. put your server in the plugin settings (DMS UI → Plugins → Mail Checker,
#    or edit plugin_settings.json with dms stopped)
```

Only `imapHost`/`username` are missing — the widget shows an error state until
they are set.

## Launching plugins from the shell

- **Launcher-type plugins** (e.g. calculator): `arch-menu menus launcher` and
  type, or `dms ipc call launcher openQuery <term>`.
- **Bar-widget plugins**: on the bar (above). Their popouts open by clicking
  the pill — no IPC to open the popout exists for these two.
- DMS has no plugin IPC targets (`dms ipc call <pluginId>` → "Target not
  found") — plugin authors can add them, these two did not.

## Removing

`omarchy-plugin-remove <id>` uninstalls cleanly; also delete its id from the
bar widget lists (same stop-edit-start dance) or the bar logs a missing widget.
