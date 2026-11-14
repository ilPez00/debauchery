# Installing debauchery

One entrypoint, twelve modules, every step reversible.

## Requirements

* Debian 13 (trixie), `sudo` available, `~/.local/bin` on `PATH`
* ≥ 5 GiB free on `/` (the AUR modules refuse below that — this box has filled
  its rootfs during an image pull once already)
* For the `feel` profile: `trixie-backports` (Hyprland, uwsm)
* For the `arch` profile: `distrobox` + `podman` (`trixie` main), rootless subuids

## Quick start

```bash
git clone https://github.com/ilPez00/debauchery.git ~/debauchery
cd ~/debauchery
./install.sh doctor                  # read-only: what is present, what drifted
./install.sh install --dry-run       # prints every command first
./install.sh install                 # the default profile: core
./install.sh doctor                  # must be green before you trust it
```

`./install.sh` with no arguments opens the whiptail menu on a TTY (and prints
`status` when piped — agents get a table, not a prompt).

## Profiles

| Profile | Modules | Root? |
|---|---|---|
| `core` (default) | backup, bridge, ssh, zsh | no |
| `feel` | + hyprland, hyprcfg, binds, shims, physis | yes (hyprland only) |
| `arch` | + archbox, tools | yes (archbox only) |
| `apple` | + fnrow | no |
| `all` | everything | yes |

Order is fixed by `modules.conf`; the installer never reorders dependencies.

## Flags

| Flag | Meaning |
|---|---|
| `--profile NAME` | one of the profiles above |
| `--only a,b` | run exactly these module ids (overrides the profile) |
| `--dry-run` | print the module and its command, change nothing |
| `--yes` | never prompt; if sudo needs a password, root modules are skipped with a message |
| `--no-sudo` | skip every root module explicitly |
| `--json` | `doctor` only: machine-readable result |

Exit codes: `0` healthy, `1` warnings, `2` failure or bad preflight. Every run
logs to `~/.local/state/debauchery/install-<timestamp>.log`.

## Commands

```bash
./install.sh status                # modules + repo-vs-deployed drift
./install.sh doctor [--json]       # read-only health report
./install.sh install [flags]       # apply modules
./install.sh update                # git pull --ff-only, re-apply, doctor
./install.sh binds niri|omarchy    # switch the keybind profile
./install.sh set KEY=VALUE         # e.g. set DEBAUCHERY_BINDS=omarchy
./install.sh get KEY
./install.sh uninstall [--all]     # undo user-scope; --all prints system undo
```

## Configuration

`~/.config/debauchery/config` (defaults and comments:
`configs/debauchery/config.example`).

| Key | Default | Effect |
|---|---|---|
| `DEBAUCHERY_PROFILE` | `core` | profile used by `update` |
| `DEBAUCHERY_BINDS` | `niri` | `niri` or `omarchy` keybind profile |
| `DEBAUCHERY_BOX` | `arch-omarchy` | container name |
| `DEBAUCHERY_BOX_IMAGE` | `quay.io/archlinux/archlinux:latest` | pin a digest if you want reproducibility |
| `DEBAUCHERY_MIN_DISK_G` | `5` | preflight gate for container/AUR work |
| `DEBAUCHERY_THEME` | `chadracula` | DMS theme (cosmetic) |

## What lands where

| Path | From |
|---|---|
| `~/.local/bin/omarchy-arch`, `pacman`, `yay`, `paru` | `configs/bin/omarchy-arch` |
| `~/.local/bin/omarchy-pkg`, `omarchy-pkg-*` | `configs/bin/omarchy-pkg` |
| `~/.local/bin/omarchy-shim`, `omarchy-*` verbs | `configs/bin/omarchy-shim` |
| `~/.config/omarchy-bridge/arch-debian.map` | `configs/arch-debian.map` |
| `~/.config/fleet/ssh-aliases.zsh` | `configs/zsh/ssh-aliases.zsh` |
| `~/.config/debauchery/aliases.zsh` + a `source` line in `~/.zshrc` | `configs/zsh/debauchery.zsh` |
| `~/.config/hypr/*.conf` | `configs/hypr/*.conf` |
| `~/.config/hypr/binds.conf` | `configs/hypr/binds.conf` (niri) or `configs/binds/omarchy.conf` |

Every replaced file keeps a `.pre-debauchery` copy (or `.pre-hyprland`,
`.pre-bridge` / `.pre-aliases` for the older scripts). `uninstall` restores them.

## For agents

`AGENTS.md` is the non-interactive contract: flags only, `doctor --json`, exit
codes, log path, and the operations that are out of bounds.

## Verification gates

| Gate | Command | Expected |
|---|---|---|
| syntax | `for f in install.sh scripts/*.sh configs/bin/*; do bash -n "$f"; done` | silent |
| zsh | `zsh -n configs/zsh/*.zsh` | silent |
| health | `./install.sh doctor` | exit 0, `fails: 0` |
| binds, both profiles | `./install.sh binds omarchy && ./install.sh binds niri` | `config ok` twice |
| bridge | `./scripts/08-arch-bridge.sh --check` | no `FAILED` |
| shims | `./scripts/11-omarchy-shims.sh --check` | `23/23`, exit 0 |
| aliases | `zsh -c 'source ~/.config/debauchery/aliases.zsh; alias ar'` | `ar=omarchy-arch` |
