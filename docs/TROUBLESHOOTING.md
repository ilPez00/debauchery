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
