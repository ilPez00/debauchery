# debauchery — air system repo

Plans, scripts and configs for the **air** host (MacBook Air 2016, Debian 13):
the niri → Hyprland migration, the Arch Distrobox, an Omarchy-compatible
interface layer on DMS, the Physis omarchy adapter, and one installer.

## Install / operate

```bash
cd ~/debauchery
./install.sh doctor            # read-only health report (green before you trust it)
./install.sh selftest          # read-only smoke test + the keys worth pressing
./install.sh config            # settings: keymap, look, night filter, plugins
./install.sh                   # TUI menu on a TTY, `status` when piped
./install.sh install --dry-run # print every command first
./install.sh install --profile core|feel|arch|apple|all|system
./install.sh binds omarchy     # Omarchy keybinds; `binds niri` restores
./install.sh update            # git pull --ff-only + re-apply + doctor
sudo ./bootstrap.sh --dry-run  # full system installer: print plan
sudo ./bootstrap.sh --user NAME [--with-arch] [--autologin] [--omarchy-binds]  # install
```

Modules are declared once in `modules.conf`; flags, config keys and profiles are
in `docs/INSTALL.md`; the agent contract is `AGENTS.md`.

## Documents

| Document | Contents |
|---|---|
| `STATE.md` | **the only status document**: verified host state, packages, configs, DMS, distrobox, interface layer, disk, pending |
| `docs/CONTRACT.md` | what "feels like Omarchy" means here: verb mapping, keybind parity, deviations, stability budget |
| `docs/LUA-PORT.md` | Lua config port: status, dispatcher mapping, activation and rollback |
| `docs/INSTALL.md` | profiles, flags, config keys, what lands where, verification gates |
| `docs/TROUBLESHOOTING.md` | measured symptoms and fixes (installer, container, keys, shell) |
| `AGENTS.md` | non-interactive contract for agents: allowed commands, exit codes, never-do list |
| `PLAN.md` | Omarchy integration: options A–G verdicts, architecture, phases, risks (options record, not status) |
| `MIGRATION-niri-to-hyprland.md` | niri → Hyprland: behavior mapping, hotkey table, config translation, rollback |
| `DISTROBOX.md` | Arch Distrobox: create/configure/use/AUR/GUI export/teardown |
| `DMS-UNDER-HYPRLAND.md` | DMS under Hyprland: detection, keybinds, plugin swap, screenshots |
| `PHYSIS-ADAPTER.md` | Physis adapter: architecture, build, deploy, installer bug, mismatches |
| `ROLLBACK-AND-SAFETY.md` | Per-phase rollback, safety rules, emergency steps |

## Scripts (everything that was done)

| Script | What it does |
|---|---|
| `scripts/01-hyprland-install.sh` | Install Hyprland + session stack + Rust + distrobox/podman (root) |
| `scripts/02-hyprland-config.sh` | Deploy `configs/hypr/*.conf` + `hyprland.lua` → `~/.config/hypr/` (backs up first) |
| `scripts/03-arch-distrobox.sh` | Create + provision the Arch Distrobox (fixes sudo, installs toolchain) |
| `scripts/04-disk-reclaim.sh` | Reclaim disk (caches + re-downloadable firmware tars; `--with-root` for the root tier) |
| `scripts/05-function-row.sh` | MacBook F1–F12 / fnmode guidance (1 = macOS-like, 2 = current) |
| `scripts/06-physis-adapter.sh` | Physis adapter: test / dry-run / install / uninstall |
| `scripts/07-rollback.sh` | Per-phase rollback commands |
| `scripts/08-arch-bridge.sh` | Arch↔Debian bridge: `omarchy-arch` gateway, `pacman`/`yay`/`paru` shims, `omarchy-pkg-*` verbs, arch→deb map (`--check`, `--uninstall`) |
| `scripts/09-ssh-aliases.sh` | Fleet SSH short hops → `~/.config/fleet/ssh-aliases.zsh`, sourced from `~/.zshrc` (`--check`, `--uninstall`) |
| `scripts/10-omarchy-tools.sh` | Install the map's `arch:`/`aur:` Omarchy tools in the container and export the binaries to `~/.local/bin` (`--dry-run`, `--check`, `--export-only`) |
| `scripts/11-omarchy-shims.sh` | Deploy `omarchy-shim` + the 23 `omarchy-*` verb symlinks (`--check`, `--uninstall`) |
| `scripts/12-gen-lua-binds.py` | Regenerate the Lua bind block from `hyprctl binds -j` after a keymap change |
| `scripts/13-base-system.sh` | Base system: apt sources, packages, fonts, subuids, zsh (root) |
| `scripts/14-display-manager.sh` | ly display manager: source build, config, ly@tty1 (root) |
| `scripts/15-dms-shell.sh` | DMS + quickshell from OBS repos (root) |
| `scripts/16-session-wiring.sh` | User session: hyprland-session.service + dms symlink (user) |
| `scripts/backup-desktop.sh` | Back up desktop configs before changes |
| `scripts/create-arch-distrobox.sh` | Thin wrapper for the distrobox create step |

`install.sh` wraps these into profiles; `modules.conf` is the list it reads
(id, script, scope, profiles, check). The older scripts still run standalone.

## Directories

| Path | What |
|---|---|
| `install.sh` | The entrypoint: install / update / doctor / status / binds / set / uninstall / TUI menu |
| `bootstrap.sh` | Full system installer entrypoint (Debian netinst → Omarchy layer) |
| `modules.conf` | Module table: id, script, scope, profiles, check — the single source of order |
| `VERSION` | Version printed by `install.sh --help`, `doctor`, `status` |
| `configs/hypr/` | Hyprland config: `hyprland.lua` (active) + the `.conf` fallback set (`hyprland.conf`, `binds.conf`, `monitors.conf`, `autostart.conf`, `rules.conf`, `extra.conf`) |
| `configs/binds/` | `omarchy.conf` — the Omarchy keybind profile (`install.sh binds omarchy`) |
| `configs/bin/` | Executables deployed to `~/.local/bin` (`omarchy-arch`, `omarchy-pkg`, `omarchy-shim`) |
| `configs/debauchery/` | `config.example` — the keys `install.sh` reads from `~/.config/debauchery/config` |
| `configs/zsh/` | Shell snippets deployed to `~/.config/` (`ssh-aliases.zsh`, `debauchery.zsh`) |
| `configs/arch-debian.map` | Arch package name → Debian/container target, read by `omarchy-pkg` |
| `configs/bin/omarchy-shim` | every Omarchy verb (34): DMS, capture, plugin store, web apps |
| `configs/dms-plugins.lock.json` | the 15 DMS plugins pinned to exact commits (`dms plugins restore`, or `omarchy-plugin-lock` to refresh) |
| `configs/apt/` | Vendored OBS keyrings + sources lists (danklinux, dms, trixie-backports) |
| `configs/ly/` | ly config template + opt-in PAM autologin |
| `configs/systemd/` | hyprland-session.service (user unit) |
| `docs/` | `CONTRACT.md`, `INSTALL.md`, `INSTALLER.md`, `TROUBLESHOOTING.md`, `LUA-PORT.md` |
| `AGENTS.md` | Non-interactive contract: allowed commands, exit codes, never-do list |
| `notes/` | Status log (applied changes, disk cleanup account) |
| `backups/` | Dated config backups (git-ignored) |

## Status (2026-11-19, v0.3.0)

`./install.sh doctor` → **exit 0, 0 fails** (2 warns: the optional physis
adapter is currently absent on air). Run it with the live session env
(`HYPRLAND_INSTANCE_SIGNATURE`, `XDG_RUNTIME_DIR`) or `binds-live` reads 0.
`./install.sh status` is the executable truth; `STATE.md` is the narrative one.

- Hyprland 0.55.2 installed and running (ly auto-login); config verifies clean.
- DMS active as the shell; `xdg-desktop-portal-hyprland` **not** masked.
- Physis adapter live: unit `active`, `$XDG_RUNTIME_DIR/physis-omarchy.sock`
  present, HUD on `SUPER+SHIFT P/G/O`.
- Arch container `arch-omarchy` (rootless podman via distrobox), `paru` + `yay`,
  `impala` installed; the other AUR tools stay opt-in.
- Omarchy interface layer: `omarchy-shim` + 23 verbs, `omarchy` keybind profile
  (verified), zsh aliases (`ar`, `ap`, `om`, `deb`, …).
- Both bind profiles pass `Hyprland --verify-config`; the deployed one is still
  `niri`, so existing muscle memory is unchanged.
- Disk: **14 GB free (87 % used)** — `DEBAUCHERY_MIN_DISK_G=5` gates AUR work.
- niri remains installed and selectable as a fallback.
- System installer tier (v0.3.0): `bootstrap.sh`, scripts 13–16, vendored assets,
  container + VM gate harnesses. G1–G4 pass (G3 container root-tier proof
  2026-11-20); the live VM run is the remaining proof — see `PLAN-INSTALLER.md` §6.

## Next

1. Decide whether to switch keys: `./install.sh binds omarchy` (and back with
   `binds niri`).
2. Swap the DMS niri plugins for Hyprland-aware ones (no errors, dead weight).
3. Optional: Omarchy browser/font/theme imports (Phase 2, cosmetic).
4. Optional: Lua port of the Hyprland config (Hyprland 0.55 is Lua-first, and
   DMS's keybind editor only reads Lua).

## Safety

- Every `[SYSTEM]` step is flagged; review before running.
- niri stays installed and selectable until Hyprland is verified.
- Distrobox is for tools only, never the compositor or system services.
