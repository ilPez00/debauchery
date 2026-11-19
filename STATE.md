# air — System State (detailed)

> Snapshot 2026-11-12, after the Hyprland migration groundwork and a disk cleanup.
> Every item below was verified by command output, not assumed.

## 1. Host

| | |
|---|---|
| Hostname | `air` |
| Model | Apple `MacBookAir7,2` (MacBook Air 2016) |
| CPU | Intel Core i5-5350U @ 2.90 GHz |
| GPU | Intel HD Graphics 6000 |
| OS | Debian 13.7 (trixie) |
| Kernel | 7.2.12+deb13-amd64 |
| Root fs | `/dev/mapper/air--vg-root`, 104 GB |
| Disk free | 23 GB (77% used) — was 1.4 GB (99%) before cleanup |
| Root access | `sudo` needs a password; `pkexec` needs an Authenticate click |

## 2. Display sessions (ly)

| Session | File | Notes |
|---|---|---|
| niri | `niri.desktop` | current default; niri + DMS |
| niri (DMS) | `niri-duks.desktop` | niri + DMS |
| niri (Noctalia) | `niri-noctalia.desktop` | niri + Noctalia shell |
| Hyprland | `hyprland.desktop` | added by the hyprland package |
| Hyprland (uwsm) | `hyprland-uwsm.desktop` | added by the uwsm package |

- Display manager: **ly** (`/etc/ly/config.lua`, `waylandsessions = "/usr/share/wayland-sessions"`).
- `auto_login_session = nil` → no automatic session; the user picks at login.
- **ly auto-logins `gio` into `hyprland`** (set 2026-11-12: `auto_login_session = "hyprland"`,
  `auto_login_user = "gio"`; previous config backed up as `/etc/ly/config.lua.bak-20261112`).
  niri stays installed and untouched — log out once and the normal session menu appears.
- `~/.config/hypr/autostart.conf` imports the compositor env into systemd and starts
  `graphical-session.target`, which is what pulls in `dms.service`
  (`Requisite=graphical-session.target`; `start-hyprland` does not start that target).

## 3. Installed desktop packages

| Package | Version | Source |
|---|---|---|
| hyprland | 0.55.2+ds-1~bpo13+1 | trixie-backports |
| hyprlock | 0.9.6-1~bpo13+1 | trixie-backports |
| hypridle | 0.1.8-1~bpo13+1 | trixie-backports |
| hyprpaper | 0.8.4-1~bpo13+1 | trixie-backports |
| xdg-desktop-portal-hyprland | 1.4.1-1~bpo13+1 | trixie-backports |
| uwsm | 0.26.7+ds-2~bpo13+1 | trixie-backports |
| cargo / rustc | 1.96.1+dfsg1-2~bpo13+1 | trixie-backports |
| distrobox | 1.8.1.2-1 | trixie |
| podman | 5.4.2+ds1-2+b2 | trixie |
| dms | 2.1.2db1 | danklinux repo |
| quickshell | 0.3.2 | danklinux opensuse repo |

Binaries: `/usr/bin/{Hyprland,hyprctl,hyprlock,hypridle,hyprpaper,distrobox,podman,cargo,rustc}`.

## 4. Hyprland config (`~/.config/hypr/`)

| File | Contents |
|---|---|
| `hyprland.conf` | general/decoration/animations/input/misc/dwindle; sources the rest |
| `monitors.conf` | `eDP-1, 1440x900@60, 0x0, 1` + catch-all |
| `autostart.conf` | `exec-once = /home/gio/.local/bin/physis-selector` |
| `binds.conf` | full niri+DMS → Hyprland keybind translation |
| `rules.conf` | window rules (0.53+ `windowrule {}` syntax) |
| `extra.conf` | sourced by the Physis adapter |
| `physis-omarchy.conf` | deployed 2026-11-12 by the adapter; `SUPER+SHIFT P/G/O` |

`binds.conf` has two profiles, both verified with `Hyprland --verify-config`:

| Profile | Source | Switch |
|---|---|---|
| niri (default) | `configs/hypr/binds.conf` | `./install.sh binds niri` |
| omarchy | `configs/binds/omarchy.conf` | `./install.sh binds omarchy` |

The omarchy profile carries upstream Omarchy's key list; the seven deviations
that could not be expressed on DMS/Hyprland are listed in `docs/CONTRACT.md`.

`hyprland.conf` defines `$mainMod = SUPER` for sourced files that use the Omarchy
convention — Hyprland substitutes an undefined variable with an empty string, so
without it the adapter's binds silently became bare `P`/`H`/`O`.

Validation: `Hyprland --verify-config -c ~/.config/hypr/hyprland.conf` → **config ok**
(re-verified after the adapter deploy).

Note: Hyprland 0.55 is Lua-first; this config is hyprlang, which still works but
should be ported to Lua eventually (see `plans/`).

## 5. DMS state

- Started as a systemd user service: `dms.service`, `PartOf=graphical-session.target`,
  `ExecStart=/usr/bin/dms run --session`. It follows whichever compositor session
  is active (niri or Hyprland).
- Config: `~/.config/dms/settings.json` — theme `chadracula`, `matugenScheme
  scheme-tonal-spot`, font `MesloLGS NF`.
- IPC surface (`dms ipc call <target> <function>`): `audio`, `bar`, `brightness`,
  `clipboard`, `color-picker`, `control-center`, `dankMenu`, `dash`, `dock`,
  `file`, **`hypr`** (`openOverview`, `closeOverview`, `toggleOverview`,
  `openBinds`, `closeBinds`, `toggleBinds`), `inhibit`, `keybinds`, `launcher`,
  `lock`, `mic`, `mpris`, `night`, **`niri`** (screenshots, touchpad OSD),
  `notifications`, `outputs`, `powermenu`, `powerprofile`, `processlist`, `scratchpad`,
  `screenshot`, `settings`, `spotlight`, `spotlight-bar`, `systemupdater`, `theme`,
  `tmux`, `toast`, `tray`, `wallpaper`, `welcome`, `wellbeing`, `widget`,
  `window-rules`, `workspace-rename`.
- Installed plugins: `aiOverviewControl`, `animationRotate`, `cavaVisualizer`,
  `clipboardPlus`, `cpuThermalIndicator`, `dankKDEConnect`, `dankMenu`, `dankscale`,
  `desktopCommand`, `displayModes`, `enderPulse`, `networkIndicator`,
  **`niriWindows`**, **`niriWorkspaceBar`**, `storageMonitor`.
- The two niri-named plugins are niri-specific; under Hyprland they need replacing
  (see `DMS-UNDER-HYPRLAND.md`).

## 6. niri state (unchanged, still working)

- `niri 26.04`, config `~/.config/niri/config.kdl` with includes `dms/*.kdl` and
  the function-row binds (F1–F12 + XF86).
- Full backup of the pre-migration config: `~/debauchery/backups/2026-11-12/`.

## 6b. Physis adapter

- Installed 2026-11-12 from `~/dev/physis-next/adapters/omarchy` (v1.8.8):
  `~/.local/bin/physis-omarchy{,d}` (release build), `~/.config/hypr/physis-omarchy.conf`,
  `~/.config/systemd/user/physis-omarchy.service` (disabled until a Hyprland
  session starts it via `exec-once`), desktop entry + icon.
- `extra.conf` sources the integration; `.pre-omarchy` backups kept there.
- Under niri the unit is `inactive (dead)` and the daemon exits with
  "Hyprland session not found" — no restart loop.
- HUD rebound to `SUPER+SHIFT G` on air (`SUPER SHIFT H` is `movewindow, l`).

## 6c. Omarchy interface layer (2026-11-14)

- `~/.local/bin/omarchy-shim` + 23 `omarchy-*` symlinks (`omarchy-menu`,
  `omarchy-capture-screenshot`, `omarchy-brightness-*`, `omarchy-audio-*`,
  `omarchy-media`, `omarchy-lock`, `omarchy-theme-toggle`, …). Each verb maps to
  a DMS IPC target or a Debian binary; `omarchy-shim --check` reports backends.
- `debauchery/install.sh` 0.2.0: `install`, `update`, `doctor [--json]`,
  `status`, `binds`, `set/get`, `uninstall`, whiptail menu. Modules are declared
  once in `debauchery/modules.conf`.
- `~/.config/debauchery/config` (profile, binds profile, box, disk gate).
- `~/.config/debauchery/aliases.zsh` sourced from `~/.zshrc`: `ar`, `arb`, `aro`,
  `ap`/`ad`/`apres`/`aa`, `pac`/`pacs`/`pacu`, `deb`/`debdoc`/`debst`, `om`/`omk`.
- Verified 2026-11-14: `doctor` exit 0 (0 fails, 0 warns), both bind profiles
  `config ok`, shims `23/23`, aliases resolve in a clean zsh.
- `selftest` also checks that every `omarchy-*` verb the omarchy keymap calls
  resolves on PATH — a missing verb is a dead key, and that is now a FAIL.

## 6d. DMS plugins (2026-11-14)

- 15 plugins installed (`enderPulse` dropped, see below), pinned by `configs/dms-plugins.lock.json`
  (`dms plugins lock`, rebuilt with `dms plugins restore <lockfile>` — the repo
  copy works as the argument, no need to touch `~/.config`).
- Registry install proven 2026-11-14: `dms plugins install batteryPlus`
  (id from the manifest under `/tmp/dankdots-plugin-registry/official/plugins`).
  **A new plugin is invisible until `systemctl --user restart dms.service`**,
  and arrives `disabled` — `dms ipc call plugins enable batteryPlus` loads it.
- `dms plugins update aiOverviewControl` worked, and changed its pinned commit.
- Three niri-scoped plugins disabled under Hyprland — they query niri's IPC and
  cannot work here: `animationRotate`, `niriWorkspaceBar`, `niriWindows`.
  Re-enable with `dms ipc call plugins enable <id>`.
- `dms ipc call plugins toggle <id>` is broken in this build
  (`PLUGIN_TOGGLE_FAILED`); `enable` / `disable` work.
- `hyprpm` unused: version-locked compiled plugins can take the compositor down.
- `omarchy-plugin-{list,search,install,remove,update,lock}` (2026-11-14):
  install does install → restart `dms.service` → wait for IPC → `enable` →
  print state; remove is the inverse and restarts too, so `plugin-list` tells
  the truth. Round-trip tested on `dankCalendarAgenda` (installed, loaded,
  removed, gone from disk and from the list). 29 shim verbs now.
- `omarchy-theme-set`, `-theme-bg-set` (path-validated), `-theme-bg-next` (2026-11-14): wrappers around DMS theme/wallpaper; `bg-set` rejects missing or relative paths to avoid the silent bad-path trap.
- `omarchy-install`/`omarchy-remove` dispatchers + all upstream
  `omarchy-install-*`/`omarchy-remove-*` names deployed (symlinks): Arch-specific
  package installs routed via distrobox (`omarchy-pkg`); `dev-env <lang>` installs
  toolchains in container; terminal/browser/editor/app/pkg/tui/webapp helpers.
  Host-only targets (setup/service/security/dictation/boot/preinstalls) print a
  "Debian host config, not a container package" note and exit 2. `omarchy-tui-*`,
  `omarchy-webapp-remove-all` implemented. Verified: help/dispatch/dry-run,
  dev-env zig present, tui install+remove round-trip, host-only guard.

## 6e. Audit pass (2026-11-15)

Full sweep: `bash -n` every script (clean), `doctor` (0 fails / 1 warn: ssh),
`selftest`, `shims --check`, `tools --check`, `bridge --check`, `config`
no-TTY — all green. Fixes found and applied:

- **Dispatcher `menu` interception bug**: the special `menu)` case ran
  `omarchy-menu <args>` before longest-prefix resolution, so
  `omarchy menu keybindings` opened the *root* menu instead of the keybind
  overlay (`omarchy-menu` is a shim verb that ignores args). Special case
  removed; `omarchy menu keybindings` → `KEYBINDS_TOGGLE_SUCCESS: hypr`.
- **`omarchy-install-and-launch`** was a bare symlink to `omarchy-install`
  (dispatched "and-launch" as a package name). Now a real verb: install via
  `omarchy-install`, then run the command.
- **Deployed-drift detection**: `11-omarchy-shims.sh --check` now cmp's every
  deployed extra against its repo copy and verifies every verb symlink points
  at `omarchy-shim`. Caught a stale standalone `configs/bin/omarchy-theme-toggle`
  fighting the shim verb (deleted; shim owns `theme-toggle`).
- **Stale `.pre-debauchery` backups** in `~/.local/bin` (4) were our own
  superseded gen-1 scripts and polluted dispatcher group listings
  (`omarchy plugin` offered `add.pre-debauchery`). Removed; listings clean.
- **14 newly mapped tools installed + exported** (mise/uv/github-cli needed a
  `pacman -Syy` mirror refresh first; pacman 404s until then). Exporter now
  retries Arch-binary aliases: `github-cli`→`gh`, `bottom`→`btm` — both live
  (`gh 2.104.0`, `btm 0.15.0`). `tools --check` exit 0.
- Webapp round-trip re-verified (install → list → remove-all → empty).
- Disk: ~8.4 G free after the tool installs.

## 6f. arch menu (2026-11-15)

ArcoLinux-style post-login toggle menu: `omarchy-rice` (alias `arch-menu`,
SUPER+M). Whiptail loop in a terminal; every action also callable headless
(`arch-menu shell noctalia`, `arch-menu theme dark`, `arch-menu bar autohide`).

- **Shell toggle** (the real "change menus"): `dms.service` ↔
  `noctalia.service` — both systemd user units on `graphical-session.target`
  (noctalia 5.4.1 installed, unit verified; the niri-noctalia session does the
  same swap). Symmetric and reversible from the menu.
- **Menus**: opens dankMenu / spotlight / launcher / powermenu / keybind
  cheatsheet over DMS IPC (all verified live).
- **Bar/dock**: wraps `omarchy-bar` / `omarchy-dock` (DMS selector IPC).
- **Theme**: dark/light/wallpaper-next/pick-from-list (`omarchy theme list`).
- **Binds**: niri ↔ omarchy profile switch via `install.sh binds` (verified:
  config ok, 140 binds live).
- **Login**: `--login` waits 5 s then opens the menu unless
  `~/.config/debauchery/rice.conf` has `RICE_AT_LOGIN=0` (default on; toggle
  from the menu or `arch-menu login off`). `--install` idempotently adds the
  SUPER+M keybind and the autostart `exec-once` line.
- Deployed: `scripts/11-omarchy-shims.sh` also links `arch-menu → omarchy-rice`.

Not live-tested on purpose: the dms↔noctalia switch itself (disruptive
mid-session; swap is the same one the niri-noctalia session performs).
- Launch verbs (2026-11-14): `omarchy-launch-terminal`, `-launch-editor`, `-launch-tui`, `-launch-or-focus-tui`, `-launch-files` (xdg-terminal-exec/uwsm-app/$TERMINAL/$EDITOR; verified `launch-files /tmp` opened thunar, cwd resolution ok). 42 shim verbs.
- Web apps (Tier 2, 2026-11-14): `omarchy-launch-webapp`, `-webapp-install`,
  `-webapp-list`, `-webapp-remove`, `-launch-or-focus`. Verified with
  `https://example.com` (window class `Chromium`) and a favicon for github.com;
  `example.com` has no favicon, so the generic icon is the expected result.
  `omarchy-launch-or-focus-webapp` is deliberately absent (see CONTRACT).
- `./install.sh config` is the settings TUI (keymap, theme mode, night filter,
  layout, plugin checklist, touchpad, edit config); with no TTY it prints the
  state and the command for each setting instead.
- `enderPulse` removed 2026-11-14: its upstream repo answers 401, so
  `dms plugins update` failed for everyone. 15 plugins pinned now.
  `dms plugins update` moved `desktopCommand` and `niriWindows` to new commits.
- Loaded/unloaded after the work: 9 loaded (incl. `batteryPlus`), 6 unloaded —
  3 by the user's own choice, 3 niri-scoped disabled here.

## 7. Distrobox / podman

- `distrobox 1.8.1.2`, `podman 5.4.2`, rootless (`podman info` → `Rootless: true`).
- Subuids present: `gio:100000:65536` in `/etc/subuid` and `/etc/subgid`.
- Container `arch-omarchy` — **created 2026-11-12**, image `quay.io/archlinux/archlinux:latest`,
  home `~/.local/share/distrobox/arch-omarchy-home`. The original image
  (`quay.io/toolbx/arch-toolbox:latest`) is a *schema1* manifest that podman can no
  longer pull; `quay.io/toolbx-images/...` answers UNAUTHORIZED — do not retry those.
- The container user (`gio`, uid 1000) had **no sudo rights and no password**, so
  `pacman` could not install anything. A passwordless-sudo drop-in
  (`/etc/sudoers.d/gio` inside the container) was applied 2026-11-12 to fix this.
  (The pkexec job that wrote it reported "Request dismissed" on exit, but the
  write had already landed — `sudo -n true` succeeds and the toolchain install
  below used it.)
- Toolchain **installed and verified 2026-11-12**: `git`, `lazygit`, `btop`,
  `yazi`, `fzf`, `ripgrep`, `fd`, `bat`, `zoxide`, `nvim` — all present.
  AUR helpers **installed 2026-11-12**: `paru` (`paru-bin`) and `yay` (`yay-bin`)
  at `/usr/bin/{paru,yay}`; `omarchy-arch --bootstrap-aur` reproduces it.
- **Usage bridge deployed 2026-11-12** (`scripts/08-arch-bridge.sh`):
  `~/.local/bin/{omarchy-arch,omarchy-pkg}`, `pacman`/`yay`/`paru` and
  `omarchy-pkg-{add,drop,present,missing,install,remove,aur-add,aur-install}`
  symlinks, map at `~/.config/omarchy-bridge/arch-debian.map` (39 entries).
  Debian package preferred, container as fallback. The gateway pins the
  container `PATH` and refuses re-entry (`OMARCHY_IN_BOX=1`), because distrobox
  exports the host `~/.local/bin` into the box and the shims would otherwise
  resolve to themselves.

## 8. Disk (after cleanup)

- Freed from 1.4 GB → 23 GB free by removing rebuildable caches and the
  re-downloadable Samsung firmware tars. Full account in `notes/2026-11-12.md`.
- Since then: **8 GB free (93 % used)** as of 2026-11-14 — the AUR toolchain and
  the Omarchy layer cost ~15 GB. `DEBAUCHERY_MIN_DISK_G=5` is what stops a build
  from filling the rootfs; the installer refuses below it.
- Still large, deliberately untouched: `~/.local/share/physis-backups/pansa`
  (6.8 GB backup repo), `~/.ollama` (5.5 GB models), `~/.npm-global` (3.2 GB),
  `~/dev/physis-next/.git` (6.5 GB), `/var/lib/flatpak` (7.4 GB, needs root).

## 9. Pending / not done

- [x] Live Hyprland login test (DMS, overview, function row, media, lock) — the
      session runs Hyprland 0.55.2 with `dms.service` active (re-verified 2026-11-14).
- [ ] Swap DMS niri plugins for Hyprland-aware ones (`niriWorkspaceBar`,
      `niriWindows` still installed; no errors in the journal, dead weight only).
- [x] Make Hyprland the ly default (autologin set 2026-11-12; live).
- [x] Physis omarchy adapter deployment (2026-11-12). See `PHYSIS-ADAPTER.md`.
- [x] Physis adapter live check: unit `active`, socket
      `$XDG_RUNTIME_DIR/physis-omarchy.sock` present, `inspect` answers
      (2026-11-14 — this was listed as pending long after it passed).
- [ ] Optional: Omarchy Quickshell shell in its own session (superseded by the
      contract layer; see `docs/CONTRACT.md`).
- [ ] Lua port of the Hyprland config — **required** for DMS's keybind
      cheatsheet (`dms keybinds show hyprland` needs `hyprland.lua`). Evidence,
      the full dispatcher mapping and the gate: `docs/LUA-PORT.md`. Four
      dispatcher shapes are unverified and cannot be tested before the switch,
      so it is deliberately its own task.
- [x] Arch↔Debian usage bridge (`omarchy-arch`, `omarchy-pkg*`, arch→deb map).
- [x] Fleet SSH short-hop aliases (`~/.config/fleet/ssh-aliases.zsh`).
- [x] AUR helpers in the container: `paru` + `yay` (2026-11-12).
- [x] Omarchy interface layer (2026-11-14): `omarchy-shim` + 23 `omarchy-*` verbs,
      omarchy bind profile, zsh aliases, `install.sh` (install/update/doctor).
- [x] All five map-mapped Arch/AUR tools installed and exported to
      `~/.local/bin` on 2026-11-14: `aether` 4.32.0, `ttfx` 0.5.1, `tensaku`,
      `herdr` 0.9.5 (via `herdr-bin`; the source package is flagged obsolete and
      pins `zig=0.16.0`), `impala` 0.9.0. `./scripts/10-omarchy-tools.sh --check`
      is the truth for this list.
- [ ] Optional: root-tier cleanup (`apt-get clean`, journal vacuum,
      `flatpak uninstall --unused`) — ran 2026-11-12, gained ~0.

## 10. System installer tier (v0.3.0)

Implemented 2026-11-19 per PLAN-INSTALLER.md:

**Vendored assets (P1):**
- `configs/apt/home-AvengeMedia-danklinux.gpg` (sha256: 07072e47c3971c95d3d5afae9b392ce230f07a2f186e88c6c5ea4e875cac3dcf)
- `configs/apt/home-AvengeMedia-dms.gpg` (same key)
- `configs/apt/danklinux.list`, `configs/apt/dms.list`, `configs/apt/trixie-backports.list`
- `configs/ly/config.lua` (derived from `/etc/ly/config.lua`, autologin nil; `--autologin` sets user/session via sed)
- `configs/ly/pam-autologin` (verbatim `/etc/pam.d/ly-autologin`, opt-in only)
- `configs/systemd/hyprland-session.service` (verbatim air unit)

**Scripts (P2):**
- `scripts/lib-installer.sh` — shared helpers (ilog/iwarn/idie, require_root, preflight_debian, disk_free_g, require_disk, backup_once, atomic_install, ensure_obs_repos, systemd_available, run)
- `scripts/13-base-system.sh` — apt sources, base packages, MesloLGS NF fonts, subuids/subgids, zsh, chsh
- `scripts/14-display-manager.sh` — ly source build (pinned commit 747955ce, zig 0.17.0), config, ly@tty1, autologin opt-in
- `scripts/15-dms-shell.sh` — dms + quickshell from OBS repos
- `scripts/16-session-wiring.sh` — user-scope: hyprland-session.service + dms.service symlink
- `bootstrap.sh` — root entrypoint: runs 13→14→15→01→[03], handoff to install.sh, doctor gate, firstboot checklist

**Wiring (P3):**
- `modules.conf` — added base, dm, shell, session rows; hyprland profile += system; module_args for base/dm
- `install.sh` — usage header += bootstrap pointer; module_args for base/dm; profile += system
- `VERSION` → 0.3.0
- `README.md` — bootstrap in install/operate + scripts table + directories
- `docs/INSTALL.md` — system profile + bare metal/VM section pointing to INSTALLER.md
- `docs/INSTALLER.md` — NEW: bare-metal runbook (netinst steps, bootstrap flags, what lands where, PAM exception, verification gates, VM harness, rollback)
- `AGENTS.md` — bootstrap --dry-run allowed; sudo bootstrap requires human decision; PAM exception documented
- `docs/CONTRACT.md` — stability budget: bootstrap tier documented exceptions (ly upstream PAM, opt-in autologin, apt sources, ly@tty1)
- `STATE.md` — this section

**VM harness (P5):**
- `configs/preseed.cfg` — Debian 13 netinst preseed template
- `scripts/test-install-vm.sh` — qemu harness (ISO download, preseed serve, boot, SSH wait, doctor+selftest+binds verification)

**Verification gates (executed during build):**
- G1 syntax: `bash -n` on all scripts — PASS (this build)
- G2 dry-run: `./bootstrap.sh --dry-run` as gio — PASS (plan printed, exit 0, nothing changed)
- G3 container system tier: PENDING (requires podman + debian:trixie)
- G4 air idempotence: `./install.sh install --only session --yes` + doctor — PASS (session no-op verified; doctor fails=0, warns=2 = physis adapter absent, pre-existing drift; 141 binds live with session env)
- G5 VM harness: `bash -n scripts/test-install-vm.sh` + preseed sanity — PASS (syntax ok; live run PENDING qemu)

**Pending:**
- Live VM run (needs `sudo apt install qemu-system-x86` — user decision)
- zig tarball sha256 pin after first verified fetch (record in docs/INSTALLER.md)
- Container gate G3 execution
