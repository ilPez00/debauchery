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

Plugin verbs: `omarchy-plugin-*` — see "Tier 2" below.

Package verbs live in `configs/bin/omarchy-pkg` (see `DISTROBOX.md` §12):
`add`, `drop`, `present`, `missing`, `install`, `remove`, `aur-add`,
`aur-install`, plus `pacman` / `yay` / `paru` shims into `arch-omarchy`.

Container gateway (`omarchy-arch`, alias `arch`; `ar` is the short form):

| Command | Behavior |
|---|---|
| `omarchy-arch` | interactive Arch shell (`distrobox enter`); `exit` / `debian` returns to the host shell |
| `omarchy-arch --stop` (alias `archstop`) | stop the container — the sandbox is killed; it restarts on next use |
| `omarchy-arch --status` (alias `arb`) | host + container + gateway state |
| `omarchy-arch --os` (alias `aro`) | the container's own OS (uname shows the host kernel) |
| `omarchy-arch --bootstrap-aur` | install `paru` + `yay` in the container (needs network) |

Terminal keys (omarchy profile): `SUPER+T` = Debian host shell,
`SUPER+R` = Arch container shell, `SUPER+Return` = Debian host shell.

## Install / remove / TUI (Arch-specific via distrobox)

`omarchy-install` and `omarchy-remove` dispatch to `omarchy-install-<name>` /
`omarchy-remove-<name>` handlers. The default behavior for Arch-specific things
is to route packages through `arch-omarchy` (distrobox) via `omarchy-pkg`:

| Command | Behavior |
|---|---|
| `omarchy-install <name> [args]` | specific handler if present, else `omarchy-pkg add <name>` in container and export |
| `omarchy-install dev-env <lang>` | installs toolchain packages (ruby/node/bun/deno/go/rust/python/php/java/zig/elixir/dotnet/clojure/ocaml/scala) in container |
| `omarchy-install terminal <pkg>` | package in container + writes `~/.config/xdg-terminals.list` hint |
| `omarchy-install browser <name>` / `editor <name>` | mapped to container/aur packages |
| `omarchy-install app|pkg <pkg...>` | `omarchy-pkg add` |
| `omarchy-install tui <name> <cmd> <float\|tile> <icon>` | host `.desktop` launcher (xdg-terminal-exec) |
| `omarchy-install webapp <name> <url> [icon]` | host web app launcher |
| `omarchy-install-and-launch <pkg> [cmd...]` | install via the routing above, then run `cmd` if given |
| `omarchy-tui-install/remove/remove-all` | TUI launcher management on host |
| `omarchy-remove <name>` / `app|pkg` | `omarchy-pkg drop` or specific handler |
| `omarchy-webapp-remove-all` | remove all omarchy web app launchers |

Host-only targets (`setup-*`, `service-*`, `security-*`, `dictation-*`,
`direct-boot`, `preinstalls`) are **not** applied as blind package installs: they
print that upstream does host system config (/etc, systemd, PAM, boot, security)
and exit non-zero. Use Debian host tooling for those, or `omarchy-arch` for
Arch-only CLI tools.

All upstream `omarchy-install-*` / `omarchy-remove-*` names are deployed as
handlers (symlinks to the dispatchers) so direct calls resolve; unknown names
fall back to package add/drop in the container.

## Tier 2 — plugins, web apps, launch, themes

Omarchy has no plugin store, so there is no upstream verb to copy. These are
this layer's own names for DMS's store, and they exist because two things go
wrong by hand: a newly installed plugin is invisible until the shell restarts,
and it arrives disabled. Each verb below was exercised on air 2026-11-14.

| Verb | What it does |
|---|---|
| `omarchy-plugin-list` | `dms ipc call plugin-scan list` — `id / state / kind / name`, no network |
| `omarchy-plugin-search <term>` | searches the registry manifests (id, name, category, description); prints the **id** `install` takes |
| `omarchy-plugin-install <id>` | `dms plugins install`, restart `dms.service`, wait for IPC, `plugins enable`, print the state |
| `omarchy-plugin-remove <id>` | disable, uninstall, restart; removing something already absent exits 0 |
| `omarchy-plugin-update [<id>\|--all]` | no argument means `--all` |
| `omarchy-plugin-lock` | pins every plugin into `configs/dms-plugins.lock.json` |
| `omarchy-plugin-add <id \| git-url> [--ref <commit\|tag\|branch>]` | registry id → `plugin-install`; git URL → Omarchy-style clone, read `plugin.json` id, install as a git checkout, restart dms, enable. Refuses an already-present id. |
| `omarchy-plugin-enable/disable <id>` | direct DMS IPC (note: `dms plugins toggle` is broken in this DMS build — `PLUGIN_TOGGLE_FAILED`; use these) |
| `omarchy-plugin-git-check` | parallel `git fetch` + status over every git-backed plugin: `UP_TO_DATE \| BEHIND(n) \| AHEAD(n) \| DIVERGED \| FETCH_FAIL  id  local..remote  repo` |
| `omarchy-plugin-catalog [term]` | alias for `plugin-search` |

Web apps are Tier 2 upstream (`omarchy-launch-webapp`, `omarchy-webapp-install`)
and they are implemented here, because they need nothing Arch-specific — a
chromium-family browser with `--app` and a `.desktop` file.

| Verb | What it does |
|---|---|
| `omarchy-launch-webapp <url>` | the URL in a `--app` window; resolves the default browser only when it is chromium-family, else falls back to `chromium.desktop` |
| `omarchy-webapp-install <name> <url> [icon]` | writes `~/.local/share/applications/<name>.desktop`, fetching the favicon (google s2, then duckduckgo, then the generic `web-browser` icon — s2 answers 200 with an empty body for domains without one) |
| `omarchy-webapp-list` | name + url of every launcher whose `Exec` is `omarchy-launch-webapp` |
| `omarchy-webapp-remove <name>` | deletes the launcher and its icon; refuses a `.desktop` that is not a web app |
| `omarchy-launch-or-focus <class> <cmd...>` | focuses the first window whose class contains `<class>`, otherwise runs the command |
| `omarchy-dock [toggle\|status\|autohide\|edit]` | DMS dock; verified `DOCK_HIDE_SUCCESS`/`DOCK_SHOW_SUCCESS` |
| `omarchy-bar` | dankbar control; DMS bar IPC needs a selector (`index\|id\|name` + value) — defaults to `index 0`, override with `OMARCHY_BAR` or per-call args |
| `omarchy-rice` / `arch-menu` | ArcoLinux-style toggle menu (SUPER+M, also at login): shell dms↔noctalia, menus, bar, dock, theme, binds profile, login on/off. Headless actions: `arch-menu <action> [arg]` |

Launcher plugins open from the shell: `dms ipc call launcher openQuery <term>`
(prefills the query; the launcher shows plugin results). Bar-widget plugins
have no IPC — they are added to the bar through DMS's bar edit UI.
| `omarchy-launch-terminal [dir]` | opens `$TERMINAL` / `xdg-terminal-exec` in `dir` (default: `cmd-terminal-cwd`) via `uwsm-app` when present |
| `omarchy-launch-editor [path]` | `$VISUAL`/`$EDITOR` (default `nvim`); TUI editors run via `launch-tui`, GUI editors detached |
| `omarchy-launch-tui <cmd> [args]` | `xdg-terminal-exec --app-id=org.omarchy.<cmd> -e …` (fallback: `$TERMINAL -e`) |
| `omarchy-launch-or-focus-tui <cmd> [args]` | focus window class `org.omarchy.<cmd>`, else `launch-tui` |
| `omarchy-launch-files [path]` | `xdg-open` path (default: `cmd-terminal-cwd`) → default file manager |

Theme verbs (safe wrappers around DMS IPC):

| Verb | What it does |
|---|---|
| `omarchy-theme-set [dark\|light\|toggle]` | `dms theme <mode>` |
| `omarchy-theme-bg-set <image>` | `dms wallpaper set` but **refuses** a missing or non-absolute path, so a colour/typo cannot become a silent `file:///…` write to a non-existent file |
| `omarchy-theme-bg-next` | next wallpaper in the rotation |

Measured 2026-11-14: `launch-webapp https://example.com` produced a window with
class `Chromium`, title `example.com_/`; `launch-or-focus Chromium …` focused it
instead of running the command. `uwsm-app` is present and used to detach.

Not implemented: `omarchy-launch-or-focus-webapp` (it identifies a web app by
the `crx_<hash>` window class, and chromium on Debian reports class `Chromium`
for every `--app` window, so the hash never matches).

Still skipped on purpose: `setup-*`, `service-*`, `security-*`, `dictation-*`,
`direct-boot`, `preinstalls` (host system config, not packages — guarded, exit 2),
`linux-omarchy` (the Arch kernel), PAM and portal rewrites, gaming GPU/driver
kernel steps (the package name itself still installs in the container),
Apple-N1X/Windows-VM/hibernation/snapshot tooling, and Omarchy's agent-internal
binaries. They assume Arch, systemd system units and Omarchy's own shell; none
of them are needed for the interface, and several are the exact steps that break
a working session.

## Keybind parity

`configs/binds/omarchy.conf` is the Omarchy profile: the key list comes from
upstream `config/hypr/default/bindings/{tiling,utilities,media,clipboard}.lua`.

Switch: `./install.sh binds omarchy` — back: `./install.sh binds niri`.

The active session config is `configs/hypr/hyprland.lua` (see `docs/LUA-PORT.md`);
the hyprlang profiles are the fallback and the `install.sh binds` target.

### Matches

`SUPER+Space` menu · `SUPER+Q`/`SUPER+W` close · `SUPER+F` fullscreen ·
`SUPER+J` split · `SUPER+K` keybindings · `SUPER+L` layout
cycle · `SUPER+P` pseudo · `SUPER+S` scratchpad · `SUPER+grave` quake console ·
`SUPER+1..9` workspaces · `SUPER+Tab` next workspace · `SUPER+Return` host terminal ·
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
| D8 | `SUPER+T` | float toggle | Debian host terminal (`alacritty --class debian --title Debian`) | air's terminal split: T = Debian host, R = Arch box |
| D9 | `SUPER+R` | resize submap | Arch container terminal (`alacritty --class arch --title Arch -e omarchy-arch`) | requested; resize moved to `SUPER+SHIFT+R` |

Everything else is the niri profile's problem, not this one: `binds niri` restores
`H/J/K/L` focus and the rest exactly as they were.

## Stability budget

This layer never:

* writes to `/etc/pam.d`, masks a portal, or replaces a systemd **system** unit,
* installs a kernel, a compositor or a display manager from the AUR,
* runs the compositor or a portal inside the container,
* deletes a config without a `.pre-debauchery` copy.

**Bootstrap tier documented exceptions (v0.3.0):**
* ly upstream `installexe` installs `/etc/pam.d/ly` (normal PAM auth) — allowed, upstream-managed.
* Opt-in autologin: `14-display-manager.sh --autologin` writes `/etc/pam.d/ly-autologin` (pam_permit) — the ONE documented opt-in PAM exception.
* apt sources: `/etc/apt/sources.list.d/` (backports, OBS) and `/etc/apt/keyrings/` (vendored keys).
* `ly@tty1.service` enable / `getty@tty1.service` disable (systemd system units).

Everything user-scope is reversible with `./install.sh uninstall`; container and
compositor are removed by `scripts/07-rollback.sh`. System tier undo is printed by `bootstrap.sh --dry-run` (see `docs/INSTALLER.md`).

## Adding a verb

1. add the name to `VERBS` in `configs/bin/omarchy-shim`,
2. add its `case` branch that calls a DMS IPC target or a Debian binary,
3. `./scripts/11-omarchy-shims.sh install` — it reads `--list` and links the rest.

No second list to keep in sync.
