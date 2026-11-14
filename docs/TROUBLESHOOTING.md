# Troubleshooting

Every entry here was hit on this machine, not guessed.

Start with `./install.sh doctor` — it separates *broken* (FAIL) from *not
installed* (WARN), and the JSON form is what an agent should read.

## Installer

| Symptom | Cause | Fix |
|---|---|---|
| `sudo needs a password and there is no TTY` | non-interactive run | `sudo -v` in that shell first, or `--no-sudo` |
| `disk: … need 5G` | rootfs nearly full | `scripts/04-disk-reclaim.sh`, then retry |
| `FAIL os … (want Debian 13)` | wrong host (or inside the container) | run on the Debian host, not in `arch-omarchy` |
| `git pull refused` | local commits diverged from `origin` | resolve by hand; the installer never forces |
| Module ran but `doctor` still WARNs | check is stricter than the script (e.g. `tools` needs `impala`) | run `install --only <id>` and read its output |

## Plugins (DMS store)

Omarchy has no plugin store; DMS does, and it is the one this layer uses.

| Task | Command | Measured |
|---|---|---|
| the store | `dms plugins browse` | TUI over the registry; `dms plugins list` prints it and works without a TTY |
| the registry on disk | `ls /tmp/dankdots-plugin-registry/official/plugins` | one `<author>-<name>.json` per plugin; the `id` field is what `install` takes |
| what is installed | `dms ipc call plugins list` | `id [loaded\|disabled]`; `dms ipc call plugin-scan list` gives `id / state / kind / name` |
| turn one on/off live | `dms ipc call plugins enable\|disable <id>` | works, no shell restart |
| `toggle` | `dms ipc call plugins toggle <id>` | **always** `PLUGIN_TOGGLE_FAILED`, even on a loaded plugin — use enable/disable |
| pin everything | `dms plugins lock` | writes `~/.config/dms/plugins.lock.json` (repo + commit per plugin) |
| rebuild exactly | `dms plugins restore [lockfile]` | re-installs the pinned commits; takes a lockfile path, so the repo copy is directly usable |
| install by id | `dms plugins install <id>` | from the registry, e.g. `batteryPlus` (the manifest's `id`, not the file name) |
| update | `dms plugins update <id>\|--all` | also drops the old checkouts; `dms plugins list` marks the ones with `(update available)` |

`omarchy-plugin-install <id>` does all of this for you (install, restart, wait
for IPC, enable, print the state), and `omarchy-plugin-remove` is its inverse.
The trap below is why those verbs exist.

**A newly installed plugin is invisible until DMS restarts.** Measured
2026-11-14 with `batteryPlus`: `dms plugins install batteryPlus` reported
success and the files were on disk in `~/.config/dms/plugins/batteryPlus`, but
`plugins status` said `PLUGIN_NOT_FOUND` and `plugin-scan list` did not show it.
`plugin-scan rescan <id>` and `plugins reload <id>` both answer
`unknown pluginId` — they only act on plugins the shell already knows. The fix:

```bash
systemctl --user restart dms.service      # the bar blinks, comes back
dms ipc call plugins enable batteryPlus    # it arrives disabled
```

Installing does not change what is loaded; `enable` does. Both steps are needed.

`dms plugins lock` + a copy of `~/.config/dms/plugins.lock.json` in this repo is
what makes the shell reproducible after a reinstall — the same role the
`modules.conf` plays for the rest of the layer.

Hyprland's own plugin manager is separate: `hyprpm list` is empty and that is
deliberate. `hyprpm` plugins are compiled against the exact Hyprland commit and a
bad one takes the whole compositor with it — the opposite of the stability
budget in `docs/CONTRACT.md`. Use a DMS plugin first.

## Hotkeys stopped working

Symptom: the keyboard is fine, typing works, but `SUPER+…` does nothing.

Cause: the running Hyprland re-read a `binds.conf` that did not parse. It keeps
whatever bindings it loaded before the error (often only the three from
`extra.conf`) and does not retry when the file is fixed.

```bash
hyprctl binds -j | grep -c dispatcher   # healthy niri profile: 153
hyprctl reload                          # restores them
```

`./install.sh binds niri` now does this itself: writes atomically (a truncate
in place is a reload trigger), rolls a rejected profile back, reloads, and fails
if fewer than 20 binds are live. `doctor` has a `binds-live` check for the same
thing.

Do not chase the `hyprland.conf at line 14` half of a config error: line 14 is
`source = ~/.config/hypr/binds.conf`, and the message repeats the inner error
from the sourced file after the second colon.

## Container (`arch-omarchy`)

| Symptom | Cause | Fix |
|---|---|---|
| `state: stopped (starts on next use)` | normal — podman stops idle containers | next `omarchy-arch` call restarts it (~0.4 s) |
| `distrobox create` hangs at 0 bytes | `quay.io/toolbx/arch-toolbox` is a **schema1** manifest podman dropped | use `quay.io/archlinux/archlinux:latest` (already the default) |
| `UNAUTHORIZED` pulling `quay.io/toolbx-images/...` | registry auth | do not retry; use the image above |
| `newuidmap: write to uid_map failed` | no subuids | `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 gio`, re-login |
| `pacman` inside the box says "not root" | invoking `pacman -S` through plain `omarchy-arch` (runs unprivileged) | use the `pacman` shim: `pacman -S …`, or `omarchy-pkg add …` |
| `paru` resolves to the host shim | distrobox exports the host `PATH` into the box | already fixed: the gateway pins the container `PATH`, sets `OMARCHY_IN_BOX=1`, and inside an Arch container the shims hand off to `/usr/bin/<name>` |
| `omarchy-arch uname -a` says Debian | containers share the host kernel — expected | `omarchy-arch --os` |
| AUR build dies mid-way | disk filled (this box has done it) | free space, `omarchy-pkg add <pkg>` again; prefer `-bin` packages |
| `paru` prints `Ci sono 3 provider disponibili` and then fails | a package with `-bin` / `-git` variants; `--noconfirm` picks nothing and paru exits | name the variant in the map: `herdr aur:herdr-bin` |
| `zig=0.16.0 (richiesto da: herdr)` | the AUR package pins an exact toolchain Arch does not ship | use its `-bin` package instead of building |

## AUR (`omarchy-pkg aur-add`)

Measured end to end on 2026-11-14, inside `arch-omarchy`:

```
$ omarchy-pkg aur-add tensaku
→ AUR package in container: tensaku
installing tensaku...            # ~45 s, prebuilt upstream binary, rust dep not compiled
$ omarchy-pkg present tensaku    # exit 0
$ ./scripts/10-omarchy-tools.sh --export-only
[tools] tensaku: exported /usr/bin/tensaku -> /home/gio/.local/bin/tensaku
```

`pacman -Qm` inside the box is the honest list of what came from the AUR:
`aether`, `ttfx`, `tensaku`, `herdr-bin`, plus `paru-bin` and `yay-bin`.

The two failure modes above are the ones that actually happened, and both are
fixed in `configs/arch-debian.map` rather than in code. Everything else is the
existing path: `omarchy-pkg add <name>` resolves the map, then pacman, then
paru.

`herdr` is the case worth remembering: the source package is **flagged obsolete**
on the AUR (`Obsoleto: 2026-10-29`) and pins `zig=0.16.0`, so it cannot build
from repos. `herdr-bin` is 0.9.5, installed in seconds, and exports `/usr/bin/herdr`
— which is why `scripts/10-omarchy-tools.sh` resolves a `-bin` package's binary by
stripping the suffix.

## Keys and shell

| Symptom | Cause | Fix |
|---|---|---|
| `binds: omarchy profile failed --verify-config` | a dispatcher Hyprland 0.55 does not know | read the `Config error` line; `layoutmsg togglesplit` is valid, `togglesplit` alone is not |
| edits to `binds.conf` do nothing | DMS's keybind editor writes `~/.config/hypr/hyprland.lua`, which does not exist in a hyprlang config | edit `~/.config/hypr/binds.conf` (repo copy in `configs/`) |
| **every hotkey stops working at once** | the running instance re-read a `binds.conf` that did not parse (e.g. an invalid dispatcher); Hyprland keeps the binds it managed to load, often only the ones from `extra.conf`, and **never retries** | `hyprctl reload` restores them. `./install.sh binds <profile>` now writes atomically, rolls a rejected profile back, reloads and asserts the live bind count; `doctor` FAILs on `binds-live` if the session has under 20 |
| `Config error in … hyprland.conf at line 14: Config error in … binds.conf at line 54` | line 14 is the `source = ~/.config/hypr/binds.conf` line; the real error is the *inner* one after the second colon | read the innermost `Config error`, not the outer one. Nothing is wrong with the `source` line, and nothing is wrong with globbing |
| `$mainMod` binds fire on bare `P`/`H`/`O` | Hyprland substitutes an undefined variable with an empty string, and `--verify-config` still says ok | `$mainMod = SUPER` is defined in `hyprland.conf`; keep it |
| `omarchy-menu` does nothing | DMS not running, or the shim not deployed | `systemctl --user status dms`, `./scripts/11-omarchy-shims.sh --check` |
| `omarchy-capture-text` errors | `tesseract` missing | `sudo apt install tesseract-ocr`, or ignore (optional) |
| screen recording errors | `wf-recorder` missing | `sudo apt install wf-recorder` |
| touchpad toggle does nothing | device name changed | `hyprctl devices -j \| jq -r '.mice[].name'`; the shim picks `bcm\|touchpad\|trackpad` |
| `alias ar` missing in a new shell | `~/.zshrc` does not source `~/.config/debauchery/aliases.zsh` | `./install.sh install --only zsh` |

## Docs that lied

Two classes of stale doc were found and fixed in 0.2.0; keep them fixed:

* `PLAN.md` said "nothing has been applied" while `STATE.md` listed applied
  phases, and said niri stays the ly default while `ly` autologins Hyprland.
* pending items listed a Hyprland login and a Physis adapter smoke test that had
  in fact happened.

Rule: `STATE.md` is the only status document. Plans describe options.
`./install.sh status` is the executable truth.
