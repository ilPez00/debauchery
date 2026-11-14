# AGENTS.md — non-interactive contract

You are an agent operating `~/debauchery` on the Debian host **air**. This file
is the whole contract; follow it instead of exploring.

## Ground truth

```bash
cd ~/debauchery
./install.sh doctor --json     # machine-readable, read-only, exit 0 healthy
./install.sh status            # module table + drift, human
```

`doctor` exit codes: `0` no hard failures, `2` something installed is broken,
`1` warnings only (e.g. an optional module is not installed). The JSON shape:

```json
{"version":"0.2.0","host":"air","fails":0,"warns":0,
 "checks":[{"status":"PASS|WARN|FAIL","check":"<id>","detail":"<text>"}]}
```

Never infer health from a single command's exit code; `doctor` is the gate.

## Allowed without asking

| Command | Effect |
|---|---|
| `./install.sh doctor [--json]` | read-only |
| `./install.sh status` | read-only |
| `./install.sh install --dry-run` | prints commands, changes nothing |
| `./install.sh install --profile core` | user-scope: bridge, aliases, zsh |
| `./install.sh install --only <ids>` | user-scope subset |
| `./install.sh binds niri\|omarchy` | swaps `~/.config/hypr/binds.conf`, backs it up |
| `./install.sh set KEY=VALUE` | writes `~/.config/debauchery/config` |

## Requires a human decision

* `install --profile feel|arch|all` — installs or removes system packages via
  apt/pacman and can take minutes on this 2-core machine.
* `update` — moves the repo, then re-applies.
* `uninstall --all` — prints rollback commands for the compositor and container.
* Anything that runs `sudo pacman -S`, `paru -S`, or an AUR build.
* Disk below `DEBAUCHERY_MIN_DISK_G` (5 GiB): stop, do not "free a bit" by
  deleting user data.

## Never

* `git add -A`, `git push --force`, history rewrites.
* Write to `/etc/pam.d`, mask `xdg-desktop-portal-hyprland`, install a kernel or
  a compositor from the AUR.
* Run the compositor, a display portal or a systemd **system** unit inside the
  container.
* Edit `~/.config/hypr/binds.conf` directly — edit `configs/hypr/binds.conf`
  (niri) or `configs/binds/omarchy.conf` (omarchy) and re-run `binds`.
* Touch `~/.config/dms/settings.json` or the niri config; they are the fallback.

## Interpreting failures

* `preflight failed` — nothing changed; fix the named item.
* `FAIL` rows in `doctor` — an installed piece is broken. A `WARN` row for a
  module simply means it is not installed.
* `binds: '<profile>' rejected by Hyprland` — the previous `binds.conf` was
  already restored; read the innermost `Config error … at line N`, fix the repo
  copy, re-run `binds`.
* `binds-live` FAIL in `doctor` — the running session has almost no binds
  (it re-read a file that did not parse). `hyprctl reload` fixes it; do not
  restart the session.
* `git pull refused` — the clone diverged. Report it; do not force.

## Where to look

| Need | File |
|---|---|
| what each module does | `modules.conf` (one row each) |
| what "feels like Omarchy" means | `docs/CONTRACT.md` |
| install / flags / config | `docs/INSTALL.md` |
| known traps | `docs/TROUBLESHOOTING.md` |
| verified system state | `STATE.md` |
| why the architecture is this shape | `PLAN.md` |

Log every mutation you run with its gate result; if you changed files, run
`fleet-sync` (commit tracked work, push `ilPez00` remotes) before finishing.
