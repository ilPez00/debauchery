# PLAN-INSTALLER.md — debauchery as a full Omarchy+Debian system installer

> Status: plan + implementation spec (2026-11-19). Companion to `PLAN.md`
> (options record) and `docs/CONTRACT.md` (interface contract).
> Goal: **fresh Debian 13 netinst → one root command → reboot → ly →
> Hyprland + DMS + the Omarchy contract layer, `doctor` green.**

## 1. Model

Omarchy's own installer does not install Arch: `archinstall` does the OS,
Omarchy's `install.sh` does the desktop. Copy that split:

```
debian-installer (netinst; creates the user, base OS, ssh)
  └─ sudo ./bootstrap.sh [--user NAME] [--with-arch] [--autologin] [--omarchy-binds]
       ROOT TIER (new scripts 13–15 + existing 01, idempotent, standalone):
         13-base-system.sh      apt sources, base packages, fonts, subuids, zsh
         14-display-manager.sh  ly (source build, pinned), config, ly@tty1
         15-dms-shell.sh        dms + quickshell from the OBS repos
         01-hyprland-install.sh Hyprland stack + rust + distrobox/podman (exists)
         [03-arch-distrobox.sh  only with --with-arch]
       HANDOFF (runuser -u NAME, user scope):
         install.sh install --only backup,bridge,zsh,hyprcfg,binds,shims,session --yes
         [install.sh binds omarchy   only with --omarchy-binds]
         [tools module               only with --with-arch]
       GATE: install.sh doctor (as the user) + firstboot checklist
```

No custom ISO in v1. A live-build ISO is a later, separate project; the
netinst+bootstrap path gets the same UX with a fraction of the surface.

## 2. Decisions (locked for v1)

| # | Decision | Why |
|---|---|---|
| 1 | Ship the **DMS + contract layer**, not the literal Omarchy Quickshell shell | `docs/CONTRACT.md`: no PAM surgery, no portal masking; proven on air. kaiseki/basedlinux already cover literal-shell ISOs |
| 2 | Script on standard Debian 13 netinst, x86_64 | Omarchy's own model; ISO later |
| 3 | Generic x86_64; `apple` profile stays opt-in | air-specific bits (fnmode) must not be forced on other hardware |
| 4 | `physis` and fleet `ssh` stay personal/opt-in | physis needs `~/dev/physis-next`; bootstrap's handoff excludes physis |
| 5 | ly = **source build**, pinned commit `747955ce3b654039c2aab9c2dbc089c26b07953c` (codeberg.org/fairyglade/ly), zig **0.17.0** | ly is NOT in Debian (verified: no apt candidate, `dpkg -S /usr/bin/ly` empty). air runs this exact commit as `ly@tty1.service` |
| 6 | OBS repo keys **vendored into the repo** (pinned trust anchor) | reproducibility; no network key fetch. Both air keyrings are the same key, sha256 `07072e47c3971c95d3d5afae9b392ce230f07a2f186e88c6c5ea4e875cac3dcf` |
| 7 | Autologin is **opt-in** (`--autologin`), default off | air's `ly-autologin` PAM service is `pam_permit` — a security tradeoff, never a default |
| 8 | Container image stays a tag (existing open decision #2 in PLAN.md) | unchanged by this project |

## 3. Verified host facts this spec is built on (air, 2026-11-19)

- Debian 13.7, x86_64, 4 cores, 14 G free on `/`.
- apt sources: `trixie-backports.list` (`main contrib non-free-firmware`);
  OBS lists `home-AvengeMedia-danklinux.list` (quickshell 0.3.2) and
  `home-AvengeMedia-dms.list` (dms 2.1.2db1), both
  `deb [signed-by=/etc/apt/keyrings/<name>.gpg arch=amd64] https://download.opensuse.org/repositories/home:/AvengeMedia:/<name>/Debian_13/ /`.
- `dms.service` is **package-shipped** at `/usr/lib/systemd/user/dms.service`.
- Session bring-up (already in repo configs, hyprlang AND Lua):
  `exec-once = systemctl --user start hyprland-session.service`
  (`configs/hypr/autostart.conf:7`, `hyprland.lua:27`). The unit is a oneshot
  `Wants=graphical-session.target` (works around `RefuseManualStart=yes`);
  `~/.config/systemd/user/graphical-session.target.wants/dms.service` pulls the
  shell. The unit has **no [Install]** — it is started by the compositor
  autostart, not enabled. Do not "fix" this.
- ly: zig build (`zig build`, install `zig build installexe -Dinit_system=systemd`,
  or `installnoconf` to keep an existing config). Deps per upstream readme:
  `build-essential libpam0g-dev libxcb-xkb-dev xauth xserver-xorg brightnessctl`.
  zig 0.17.0 toolchain on air: `/opt/zig-x86_64-linux-0.17.0/zig` (verified
  `zig version` → 0.17.0; `/usr/bin/zig` is 0.6.0 — too old, never use it).
  Build clone on air: `/opt/ly`. Runs as `ly@tty1.service` (active);
  `getty@tty1.service` inactive.
- `/etc/pam.d/ly` ships with ly's own install (upstream-managed, not our
  surgery). `/etc/pam.d/ly-autologin` = `pam_permit` (opt-in only, §4.4).
- MesloLGS NF fonts live in `~/.fonts` on air (4 ttfs, romkatv/powerlevel10k-media).
- `/etc/subuid` + `/etc/subgid`: `gio:100000:65536`.
- No qemu installed; `/dev/kvm` exists; podman rootless works; docker daemon down.

## 4. New files — exact specs

Common rules for every new script:
- `#!/bin/bash`, `set -euo pipefail`, usage header comment like the existing scripts.
- Idempotent: check-before-change; re-run on a finished system = no-op health pass.
- Back up any existing file before replacing: `<file>.pre-debauchery` (once).
- Atomic writes: write `<file>.new` then `mv -f` (Hyprland/systemd watch inotify).
- `--dry-run` flag: print every mutation, change nothing. Must work unprivileged.
- Container mode: `[ -d /run/systemd/system ]` false → skip ALL systemctl calls,
  note it in the log, continue (package/file steps still run). This is the CI gate.
- Log to stdout; bootstrap additionally tees to `/var/log/debauchery-bootstrap-<ts>.log`.
- Exit codes: 0 ok, 1 warnings, 2 failure (match install.sh).
- Never: write `/etc/pam.d` except ly's upstream install + the opt-in autologin
  file; mask any portal; touch an existing `/etc/ly/config.lua` without backup;
  run on non-Debian-13 / non-x86_64 (preflight die).

### 4.1 `scripts/lib-installer.sh` (sourced, not executed)
Helpers shared by 13/14/15/bootstrap:
- `ilog`, `iwarn`, `idie` (printf, exit 2).
- `require_root` (die unless euid 0, except when DRY_RUN=1).
- `preflight_debian` — `. /etc/os-release`; ID=debian, VERSION_ID=13, `uname -m`=x86_64.
- `disk_free_g` / `require_disk G`.
- `backup_once FILE` — cp -a to `.pre-debauchery` if absent.
- `atomic_install SRC DST MODE` — backup_once + install to .new + mv.
- `ensure_obs_repos` — install the two vendored keyrings (§4.6) to
  `/etc/apt/keyrings/` and the two `.list` files to `/etc/apt/sources.list.d/`
  (atomic_install), then `apt-get update`. Idempotent via cmp.
- `systemd_available` — `[ -d /run/systemd/system ]`.
- `DRY_RUN=${DRY_RUN:-0}`; `run()` wrapper exactly like install.sh's single gate.

### 4.2 `scripts/13-base-system.sh` (root)
Args: `--user NAME` (default: `$SUDO_USER`, else first passwd uid 1000–60000),
`--dry-run`. Env `DEBAUCHERY_TARGET_USER` overrides.
1. preflight (Debian 13 x86_64, ≥10 G free, root unless dry).
2. `apt-get update`; install base set (one apt call, `--no-install-recommends`
   NOT used — recommends are wanted here):
   `sudo zsh git curl ca-certificates gnupg whiptail networkmanager pipewire
   wireplumber bluez brightnessctl playerctl grim slurp wl-clipboard alacritty
   chromium wf-recorder tesseract-ocr fonts-noto-color-emoji`
   (wf-recorder/tesseract are the shim's optional capture deps — install them
   so the omarchy keymap has no dead keys; drop from the list only if apt fails
   on them, with a warning).
3. non-free-firmware: if no existing trixie source line contains
   `non-free-firmware`, write `/etc/apt/sources.list.d/debian-nonfree.list`:
   `deb http://deb.debian.org/debian trixie non-free-firmware` (component-only
   line; do not edit the installer's own sources files).
4. backports: atomic_install `configs/apt/trixie-backports.list` →
   `/etc/apt/sources.list.d/trixie-backports.list` (content exactly air's:
   `deb http://deb.debian.org/debian trixie-backports main contrib non-free-firmware`).
5. `ensure_obs_repos` (§4.1).
6. MesloLGS NF system-wide: download the 4 ttfs from
   `https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20{Regular,Bold,Italic,Bold%20Italic}.ttf`
   into `/usr/local/share/fonts/meslolgs/` (skip files already present; curl
   -fL --retry 3; on download failure warn and continue — fonts are cosmetic).
   `fc-cache -f` if fontconfig present.
7. target user must exist (die with "create it in debian-installer or useradd"
   if not — v1 does not create users). Ensure `~/.local/bin` exists (owned by
   the user). If `~/.zshrc` absent, create a minimal one: comment header +
   `export PATH="$HOME/.local/bin:$PATH"` (install.sh's wire_zshrc needs the
   file to exist). chown to the user.
8. subuids/subgids: if the user has no `/etc/subuid` entry, allocate the next
   free 65536 range (parse existing entries' max end; start 100000 if empty)
   via `usermod --add-subuids A-B --add-subgids A-B`. Same for subgid. Skip if present.
9. `chsh -s /usr/bin/zsh NAME` (record previous shell in the log).
10. container mode: skip nothing except systemctl (none here); chsh/usermod work.

### 4.3 `scripts/14-display-manager.sh` (root)
Args: `--user NAME`, `--session hyprland` (default), `--autologin`, `--dry-run`.
1. If `command -v ly` AND `/etc/ly/config.lua` exists → log "ly present", skip
   build; go to step 6 (service wiring) — never rebuild over a working ly.
2. apt deps: `build-essential libpam0g-dev libxcb-xkb-dev xauth brightnessctl git`.
3. zig 0.17.0: probe `/opt/zig-x86_64-linux-0.17.0/zig`, `/opt/zig/zig`,
   `command -v zig` — accept only `zig version` = 0.17.0. Else download
   `https://ziglang.org/download/0.17.0/zig-x86_64-linux-0.17.0.tar.xz`,
   verify sha256 (record the observed hash in docs/INSTALLER.md on first
   successful fetch; until then warn that the hash is unpinned), extract to
   `/opt/zig-x86_64-linux-0.17.0`. Use the found binary as `$ZIG`.
4. Clone `https://codeberg.org/fairyglade/ly` → `/usr/local/src/ly` (if absent),
   `git fetch origin && git checkout 747955ce3b654039c2aab9c2dbc089c26b07953c`.
   Build: `"$ZIG" build` then install:
   - no `/etc/ly/config.lua` → `"$ZIG" build installexe -Dinit_system=systemd`
   - existing config → `"$ZIG" build installnoconf -Dinit_system=systemd`
   (upstream install ships `/etc/pam.d/ly` and the systemd units — that is
   package-like upstream behavior, allowed; log it.)
5. Config: only if `/etc/ly/config.lua` is absent, render
   `configs/ly/config.lua` (§4.6) substituting `__USER__`/`__SESSION__`.
   If present: backup_once, leave untouched (air's autologin config survives).
   `--autologin` (explicit flag only): render the autologin lines into the
   config (auto_login_user/session/service="ly-autologin") with backup, and
   atomic_install `configs/ly/pam-autologin` → `/etc/pam.d/ly-autologin`
   (content = air's file, §3; this is the ONE documented PAM exception,
   opt-in, backed up). Without the flag, never write either.
6. systemd mode only: `systemctl enable ly@tty1.service`,
   `systemctl disable getty@tty1.service` (both idempotent). If gdm3/lightdm/sddm
   is enabled → disable it and warn (one display manager). Container mode: skip.
7. Verify: `command -v ly`, config parses as Lua if `luac`/`lua` present
   (optional, warn-only), print the service state.

### 4.4 `scripts/15-dms-shell.sh` (root)
1. preflight + `ensure_obs_repos` (standalone-safe).
2. `apt-get install -y dms quickshell` (OBS provides both; backports not needed).
3. Log installed versions (`dpkg-query -W dms quickshell`) — the repro record.
4. Verify `/usr/lib/systemd/user/dms.service` exists (package-shipped).
5. No config writes here — DMS settings are user scope and the fallback
   (AGENTS.md: never touch `~/.config/dms/settings.json`).

### 4.5 `scripts/16-session-wiring.sh` (USER scope — runs as the desktop user)
1. atomic_install `configs/systemd/hyprland-session.service` →
   `~/.config/systemd/user/hyprland-session.service` (verbatim air unit, §4.6).
2. `mkdir -p ~/.config/systemd/user/graphical-session.target.wants`;
   symlink `dms.service` → `/usr/lib/systemd/user/dms.service` (ln -sfn, only if
   the target exists; skip with warning otherwise).
3. `systemctl --user daemon-reload` (skip in container mode / no user bus).
   Do NOT start graphical-session.target (RefuseManualStart) and do NOT enable
   hyprland-session.service (no [Install]; the compositor autostart starts it —
   already present in configs/hypr/autostart.conf and hyprland.lua).
4. Verify: `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` (or .conf
   fallback) if Hyprland present; report. Check the autostart line exists in
   the deployed config; warn if not.
5. `--check` flag: read-only report (used by modules.conf check + doctor).

### 4.6 Vendored assets (copy from air, all world-readable)
- `configs/apt/home-AvengeMedia-danklinux.gpg` ← `/etc/apt/keyrings/…` (sha256 above)
- `configs/apt/home-AvengeMedia-dms.gpg` ← same content, air's second name
- `configs/apt/danklinux.list`, `configs/apt/dms.list` — air's exact lines (§3)
- `configs/apt/trixie-backports.list` — air's exact line (§3)
- `configs/ly/config.lua` — render from `/etc/ly/config.lua` with
  `auto_login_user`/`auto_login_session` set to `nil`, autologin block
  commented, `__USER__`/`__SESSION__` placeholders where the installer
  substitutes (waylandsessions path stays `/usr/share/wayland-sessions`).
  Keep every other setting air has (it is the verified-good config).
- `configs/ly/pam-autologin` — verbatim `/etc/pam.d/ly-autologin` (§3), with a
  header comment: OPT-IN ONLY, pam_permit = passwordless login, installed
  solely by `14 --autologin`.
- `configs/systemd/hyprland-session.service` — verbatim air unit:
  ```
  [Unit]
  Description=Bring up graphical-session.target for a Hyprland session
  Documentation=man:systemd.special(7)
  Wants=graphical-session.target
  After=graphical-session.target

  [Service]
  Type=oneshot
  RemainAfterExit=yes
  ExecStart=/bin/true
  ```

### 4.7 `bootstrap.sh` (repo root, the new entrypoint)
- Flags: `--user NAME`, `--with-arch`, `--autologin`, `--omarchy-binds`,
  `--skip-handoff`, `--dry-run`, `--yes`, `-h`.
- `--dry-run`: works as any user, prints the full ordered plan (each script +
  args + the handoff command), changes nothing, exit 0.
- Mutating run: require root; preflight (Debian 13 x86_64, ≥10 G, network via
  `apt-get update -qq`); resolve target user (§4.2 default); die if absent.
- Export `DEBAUCHERY_TARGET_USER`; run in order, stopping on first failure:
  `13 --user U` → `14 --user U [--autologin]` → `15` → `01` →
  [`03` if --with-arch]. Pass DRY_RUN through.
- Repo for the handoff: if the repo dir is not owned by the target user,
  `cp -a` it to `/home/U/debauchery` and `chown -R U:U` (exclude nothing;
  backups/ is git-ignored but small). Use that path for the handoff.
- Handoff (unless --skip-handoff):
  `runuser -u U -- env HOME=/home/U PATH=/home/U/.local/bin:/usr/local/bin:/usr/bin:/bin
   bash /home/U/debauchery/install.sh install --only backup,bridge,zsh,hyprcfg,binds,shims,session --yes`
   (+`,tools` with --with-arch; `binds omarchy` afterwards with --omarchy-binds).
   NOTE: `ssh` and `physis` are deliberately excluded (personal, §2.4).
- Gate: same runuser → `install.sh doctor`; print exit code meaning.
- Finish: firstboot checklist (reboot; ly picker or autologin; SUPER+Space menu;
  `~/debauchery/install.sh selftest`; niri fallback session still listed).
- Log: tee everything to `/var/log/debauchery-bootstrap-<ts>.log`.

### 4.8 VM gate harness (written now, live run later)
- `configs/preseed.cfg` — Debian 13 netinst preseed template: locale en_US,
  UTC, hostname `debauchery-vm`, guided LVM entire disk, user `__USER__` with
  password hash `__PASSWORD_HASH__` (substituted at runtime from
  `DEBAUCHERY_VM_PASSWORD_HASH` — NEVER commit a real hash; document
  `mkpasswd -m sha-512`), ssh server installed, no tasksel desktop,
  late_command: clone `https://github.com/ilPez00/debauchery.git` to the user's
  home and run `bootstrap.sh --user __USER__ --yes --autologin --omarchy-binds`
  (throwaway VM only), finish reboot.
- `scripts/test-install-vm.sh` — requires qemu-system-x86_64 + /dev/kvm (die
  with the exact `sudo apt install qemu-system-x86` hint if absent); downloads
  the pinned trixie netinst ISO (URL + sha256 in the script header, verify);
  creates a 12 G qcow2 in `$STATE/vm/`; serves the rendered preseed via
  `python3 -m http.server` on 127.0.0.1; boots qemu user-mode net with
  `hostfwd=tcp::2222-:22`, kernel args `auto=true url=http://10.0.2.2:<port>/preseed.cfg`
  (netinst ISO's gtk initrd supports preseed via appended args — use the
  documented `install` label approach); waits for ssh (timeout 40 min, poll
  every 15 s); then over ssh: `install.sh doctor --json` (assert fails=0),
  `install.sh selftest` automatic part, `hyprctl binds -j` count ≥ 20 after
  autologin; prints PASS/FAIL report; `--keep` leaves the VM disk for debugging.
- This harness is bash -n gated in v1; the live VM run is PENDING (qemu not
  installed; needs root — hand the user the sudo command).

## 5. Edits to existing files

- `modules.conf` — append rows (keep format, order = execution order; place
  root rows before the existing hyprland row is NOT required — append at end,
  bootstrap calls scripts directly; rows exist for doctor/status/incremental):
  ```
  base    |scripts/13-base-system.sh    |root|system,all|bash -c '. /etc/os-release && [ "$VERSION_ID" = 13 ] && grep -rqs trixie-backports /etc/apt/sources.list.d/ && command -v zsh'
  dm      |scripts/14-display-manager.sh|root|system,all|command -v ly
  shell   |scripts/15-dms-shell.sh      |root|system,all|bash -c 'dpkg-query -W -f="\${Status}" dms 2>/dev/null | grep -q "install ok installed" && dpkg-query -W -f="\${Status}" quickshell 2>/dev/null | grep -q "install ok installed"'
  session |scripts/16-session-wiring.sh |user|feel,system,all|bash -c 'test -f "$HOME/.config/systemd/user/hyprland-session.service" && test -L "$HOME/.config/systemd/user/graphical-session.target.wants/dms.service"'
  ```
  Add `system` to the `hyprland` row's profiles. New profile `system` =
  base, dm, shell, hyprland, session (document in header comment).
  `module_args()` in install.sh: pass `--user "$SUDO_USER"` to base/dm when
  invoked via install.sh (bootstrap passes it explicitly).
- `install.sh` — usage header: add the bootstrap pointer line; `module_args`
  case for base/dm (§ above). NOTHING else changes (preflight still refuses
  root — bootstrap is the root entrypoint, install.sh stays user-scope).
- `VERSION` → `0.3.0`.
- `README.md` — add bootstrap to Install/operate + scripts table + directories;
  "Status" untouched (STATE.md owns status).
- `docs/INSTALL.md` — new "Bare metal / VM (full system)" section pointing at
  docs/INSTALLER.md; profiles table gains `system`.
- `docs/INSTALLER.md` — NEW: the bare-metal runbook (netinst steps, bootstrap
  flags, what lands where at system scope, the PAM exception, verification
  gates, VM harness usage, rollback: system tier undo = apt remove + ly unit
  disable + sources removal, all printed by `bootstrap.sh --dry-run` inverse
  notes; user tier undo unchanged).
- `AGENTS.md` — add: `./bootstrap.sh --dry-run` allowed read-only;
  `sudo ./bootstrap.sh …` requires a human decision; the opt-in PAM exception
  is the only /etc/pam.d write ever permitted, and only via `14 --autologin`.
- `docs/CONTRACT.md` — stability budget: note the bootstrap tier's documented
  exceptions (ly upstream PAM install; opt-in autologin file; apt sources;
  ly@tty1 enable). Everything else in the budget stands.
- `STATE.md` — new "System installer tier (v0.3.0)" section: what exists,
  what was verified (container gate, dry-run, doctor), what is pending (live
  VM run, zig sha256 pin after first fetch).
- `notes/2026-11-19.md` — build log: what was implemented, gate results.

## 6. Verification gates (executed during this build, in order)

| # | Gate | Command | Pass | Result |
|---|---|---|---|---|
| G1 | syntax | `for f in install.sh bootstrap.sh scripts/*.sh; do bash -n "$f"; done` | silent | **PASS** |
| G2 | dry-run | `./bootstrap.sh --dry-run` (as gio, no root) | full plan printed, exit 0, nothing changed | **PASS** |
| G3 | container system tier | podman debian:trixie, repo mounted ro, run 13→14→15→01 as root inside (container mode) | apt sources present; dms+quickshell+hyprland installed; `/usr/bin/ly` built; no systemctl attempted | **PENDING** (needs podman) |
| G4 | air idempotence | `./install.sh install --only session --yes` then `./install.sh doctor --json` | session module no-op/current; doctor fails=0 | **PASS** |
| G5 | VM harness | `bash -n scripts/test-install-vm.sh` + preseed sanity | syntax ok; live run PENDING qemu (root) | **PASS** (syntax) |

G3 is the real proof of the root tier without touching air. air has 14 G free;
the container build (zig toolchain reuse: mount /opt/zig-x86_64-linux-0.17.0 ro
into the container to skip the 50 MB download; ly build ~2–4 min on 4 cores)
fits. Pull `docker.io/library/debian:trixie` first (~120 MB).

**Never during this build:** mutating bootstrap on air itself (working host,
root needs a password anyway — hand root commands to the user), any
`systemctl` system change on air, any portal/PAM write on air.

## 7. Premortem

| Failure | Mitigation in spec |
|---|---|
| bootstrap clobbers air's ly autologin config | 14 skips build when ly present; config untouched without backup; autologin opt-in |
| OBS repo/key drift breaks installs | keys vendored + sha256 recorded; versions logged at install |
| zig version mismatch (0.6 in PATH) | probe accepts ONLY 0.17.0; pinned tarball fallback |
| fresh user has no .zshrc → wire_zshrc fails | 13 creates minimal .zshrc + ~/.local/bin |
| rootless podman fails (no subuids) | 13 allocates next free range, idempotent |
| handoff runs root modules with password prompt | --only list excludes all root modules; --yes |
| physis module fails on fresh host (no checkout) | excluded from handoff |
| session unit "fixed" with [Install] breaks bring-up | spec forbids; autostart mechanism documented (§3) |
| VM disk fills air | 12 G qcow2 + 10 G gate; harness lives in $STATE/vm, --keep optional |
| worker script bugs reach the host | G1–G4 before commit; container gate is the mutation sandbox |

## 8. Phases

- [x] P1 vendored assets (§4.6) + this plan
- [x] P2 lib + scripts 13–16 + bootstrap.sh (§4.1–4.7)
- [x] P3 wiring: modules.conf, install.sh, VERSION, docs (§5)
- [ ] P4 gates G1–G4 (§6)
- [x] P5 VM harness written + G5 (§4.8)
- [x] P6 commit (specific files, never -A) + push; STATE/notes updated (fleet-sync deferred: user asked to push this work only)

## 9. After v1 (open, not in this build)

1. Live VM run (needs `sudo apt install qemu-system-x86` — user decision).
2. zig tarball sha256 pin after first verified fetch.
3. apt version pinning / snapshot.debian.org for full reproducibility.
4. live-build ISO (separate project; kaiseki is the reference).
5. `--create-user` path (useradd + passwd) for hosts without debian-installer.
6. Hardware tier beyond apple (broadcom wl, nvidia) — only if a non-air target appears.
