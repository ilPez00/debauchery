# Bare-metal / VM installer runbook (v0.3.0)

> **Goal:** Fresh Debian 13 netinst → one root command → reboot → ly → Hyprland + DMS + Omarchy contract layer, `doctor` green.

This document covers the `bootstrap.sh` entrypoint and the system installer tier (scripts 13–16). For the user-scope layer (`install.sh`), see `docs/INSTALL.md`.

## 1. Prerequisites

- Debian 13 (trixie) netinst, x86_64
- Target user already created (debian-installer or `useradd`)
- `sudo` available, root access
- ≥ 10 GiB free on `/` (root tier needs space for zig, ly build, packages)
- Network (apt, git, zig download)

## 2. Quick start

```bash
# On the target machine (as root or via sudo):
git clone https://github.com/ilPez00/debauchery.git ~/debauchery
cd ~/debauchery

# Preview the full plan (works as any user):
./bootstrap.sh --dry-run

# Install (replace NAME with the target username):
sudo ./bootstrap.sh --user NAME [--with-arch] [--autologin] [--omarchy-binds]

# After reboot:
# - ly session picker (or autologin into hyprland if --autologin)
# - SUPER+Space → menu opens
# - ~/debauchery/install.sh selftest
# - niri fallback session still listed in ly
```

## 3. bootstrap.sh flags

| Flag | Meaning |
|---|---|
| `--user NAME` | Target user (default: `$SUDO_USER`, else first uid 1000–60000) |
| `--with-arch` | Include Arch distrobox (runs `scripts/03-arch-distrobox.sh`) |
| `--autologin` | Enable ly autologin (opt-in: writes `/etc/pam.d/ly-autologin` + config) |
| `--omarchy-binds` | Apply omarchy keybind profile after handoff |
| `--skip-handoff` | Stop after root tier (no user-scope `install.sh` run) |
| `--dry-run` | Print full ordered plan, change nothing (works as any user) |
| `--yes` | Never prompt; if sudo needs password, root modules skipped with message |

## 4. What runs (in order)

### Root tier (system scope)

| Step | Script | What it does |
|---|---|---|
| 1 | `scripts/13-base-system.sh` | apt sources (backports, non-free-firmware, OBS), base packages, MesloLGS NF fonts, target user `~/.local/bin` + minimal `.zshrc`, subuids/subgids, `chsh -s zsh` |
| 2 | `scripts/14-display-manager.sh` | ly from source (pinned commit `747955ce`, zig 0.17.0), config with `__USER__`/`__SESSION__` placeholders, `ly@tty1.service` enable, `getty@tty1` disable, other DMs disabled |
| 3 | `scripts/15-dms-shell.sh` | `dms` + `quickshell` from vendored OBS repos |
| 4 | `scripts/01-hyprland-install.sh` | Hyprland stack + Rust + distrobox/podman from trixie-backports |
| 5 | `scripts/03-arch-distrobox.sh` | *(only with `--with-arch`)* Arch distrobox create + provision |

### Handoff (user scope)

```bash
runuser -u USER -- env HOME=/home/USER PATH=/home/USER/.local/bin:/usr/local/bin:/usr/bin:/bin \
  bash /home/USER/debauchery/install.sh install --only backup,bridge,zsh,hyprcfg,binds,shims,session --yes
# + ,tools with --with-arch
# then: install.sh binds omarchy (with --omarchy-binds)
```

**Deliberately excluded:** `ssh`, `physis` (personal/opt-in, per `docs/CONTRACT.md`).

### Gate

```bash
runuser -u USER -- bash /home/USER/debauchery/install.sh doctor
```

Exit codes: `0` healthy, `1` warnings, `2` failures.

## 5. Vendored assets (reproducibility)

All external keys and sources are vendored in the repo — no network key fetch at install time.

| Asset | Source (air) | Destination |
|---|---|---|
| `configs/apt/home-AvengeMedia-danklinux.gpg` | `/etc/apt/keyrings/home-AvengeMedia-danklinux.gpg` | `/etc/apt/keyrings/` |
| `configs/apt/home-AvengeMedia-dms.gpg` | `/etc/apt/keyrings/home-AvengeMedia-dms.gpg` | `/etc/apt/keyrings/` |
| `configs/apt/danklinux.list` | air's exact line | `/etc/apt/sources.list.d/` |
| `configs/apt/dms.list` | air's exact line | `/etc/apt/sources.list.d/` |
| `configs/apt/trixie-backports.list` | air's exact line | `/etc/apt/sources.list.d/` |
| `configs/ly/config.lua` | derived from `/etc/ly/config.lua` | `/etc/ly/config.lua` (if absent) |
| `configs/ly/pam-autologin` | `/etc/pam.d/ly-autologin` | `/etc/pam.d/ly-autologin` (opt-in only) |
| `configs/systemd/hyprland-session.service` | air's unit verbatim | `~/.config/systemd/user/` |

**OBS key sha256 (both files identical):**
`07072e47c3971c95d3d5afae9b392ce230f07a2f186e88c6c5ea4e875cac3dcf`

## 6. ly config template

`configs/ly/config.lua` is derived from air's working config with:

- `auto_login_user = nil`
- `auto_login_session = nil`
- Autologin block commented
- `__USER__` / `__SESSION__` placeholders substituted by `14-display-manager.sh`
- `waylandsessions = "/usr/share/wayland-sessions"` preserved
- All other settings identical to air's verified config

**Autologin (opt-in, `--autologin` flag only):**
- `auto_login_user = "NAME"`
- `auto_login_session = "hyprland"`
- `auto_login_service = "ly-autologin"`
- Installs `configs/ly/pam-autologin` → `/etc/pam.d/ly-autologin` (pam_permit)

## 7. The PAM exception (stability budget)

The **only** `/etc/pam.d` write ever permitted is `/etc/pam.d/ly-autologin`, and only
when `14-display-manager.sh --autologin` is explicitly invoked. This file uses
`pam_permit.so` (passwordless login) — a documented security tradeoff, never a default.

Upstream ly's `installexe` installs `/etc/pam.d/ly` (normal PAM auth) — this is
upstream-managed and allowed.

## 8. Container mode (CI gate)

All root-tier scripts detect container mode via `[ -d /run/systemd/system ]`.
When false (no systemd), they:
- Skip ALL `systemctl` calls (enable/disable/start/stop)
- Log "Container mode: skipping systemctl"
- Continue all package/file steps

This allows the full root tier to run in `podman run --rm -v $PWD:/repo debian:trixie`
for CI verification (gate G3).

## 9. Rollback (system tier undo)

`bootstrap.sh --dry-run` prints the forward plan; the inverse of each mutation is tabulated here (manual undo — the system tier has no one-command uninstall yet):

| Tier | Undo |
|---|---|
| apt sources | `rm /etc/apt/sources.list.d/{trixie-backports,home-AvengeMedia-*}.list` + `apt-get update` |
| OBS keys | `rm /etc/apt/keyrings/home-AvengeMedia-*.gpg` |
| non-free-firmware | `rm /etc/apt/sources.list.d/debian-nonfree.list` + `apt-get update` |
| base packages | `apt-get remove -y <package list from 13-base-system.sh>` |
| MesloLGS fonts | `rm -rf /usr/local/share/fonts/meslolgs` + `fc-cache -f` |
| subuids/subgids | `usermod --del-subuids RANGE --del-subgids RANGE USER` |
| chsh | `chsh -s /bin/bash USER` (or previous shell) |
| ly build | `rm -rf /usr/local/src/ly` + zig toolchain if installed by us |
| ly binary/config | ly's upstream uninstall (or `rm /usr/bin/ly /etc/ly/config.lua /etc/pam.d/ly` + units) |
| ly@tty1 | `systemctl disable ly@tty1; systemctl enable getty@tty1` |
| dms/quickshell | `apt-get remove -y dms quickshell` |
| Hyprland stack | `apt-get remove -y hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland uwsm cargo rustc` |
| Arch distrobox | `distrobox rm -f arch-omarchy` + `podman rmi` |

User-scope undo is unchanged: `./install.sh uninstall [--all]`.

## 10. VM harness (gate G5)

`scripts/test-install-vm.sh` automates the full netinst → bootstrap → verify cycle.

```bash
# Generate password hash:
mkpasswd -m sha-512

# Run (requires qemu-system-x86_64 + /dev/kvm):
./scripts/test-install-vm.sh --password-hash '$6$...' [--keep]
```

**What it does:**
1. Downloads pinned trixie netinst ISO (URL + sha256 in script header)
2. Creates 12G qcow2 in `$STATE/vm/`
3. Renders `configs/preseed.cfg` with `__USER__`/`__PASSWORD_HASH__`
4. Serves preseed via `python3 -m http.server` on 127.0.0.1:8765
5. Boots qemu user-mode net with `hostfwd=tcp::2222-:22`
6. Kernel args: `auto=true url=http://10.0.2.2:8765/preseed.cfg`
7. Waits for SSH (40 min timeout, poll 15s)
8. Runs over SSH:
   - `install.sh doctor --json` → asserts `fails=0`
   - `install.sh selftest` → automatic part
   - `hyprctl binds -j` count ≥ 20 (after autologin)
9. Prints PASS/FAIL report; `--keep` leaves disk for debugging

**Note:** Live VM run is PENDING (qemu not installed on air; needs root).
The harness is `bash -n` gated in v1.

## 11. Verification gates (from PLAN-INSTALLER.md §6)

| # | Gate | Command | Pass |
|---|---|---|---|
| G1 | syntax | `for f in install.sh bootstrap.sh scripts/*.sh; do bash -n "$f"; done` | silent |
| G2 | dry-run | `./bootstrap.sh --dry-run` (as user, no root) | full plan printed, exit 0 |
| G3 | container system tier | `./scripts/test-install-container.sh` (podman, debian:trixie, repo ro, host zig ro) | apt sources present; dms+quickshell+hyprland installed; `/usr/bin/ly` built; no systemctl |
| G4 | air idempotence | `./install.sh install --only session --yes` then `./install.sh doctor --json` | session module no-op; doctor fails=0 |
| G5 | VM harness | `bash -n scripts/test-install-vm.sh` + preseed sanity | syntax ok; live run PENDING |

## 12. Known traps (from PLAN-INSTALLER.md §7)

| Trap | Mitigation |
|---|---|
| bootstrap clobbers air's ly autologin | 14 skips build when ly present; config untouched without backup; autologin opt-in |
| OBS repo/key drift | keys vendored + sha256 recorded; versions logged at install |
| zig version mismatch (0.6 in PATH) | probe accepts ONLY 0.17.0; pinned tarball fallback |
| fresh user has no .zshrc | 13 creates minimal `.zshrc` + `~/.local/bin` |
| rootless podman fails (no subuids) | 13 allocates next free range, idempotent |
| handoff runs root modules with password prompt | `--only` list excludes all root modules; `--yes` |
| physis module fails on fresh host | excluded from handoff |
| session unit "fixed" with [Install] | spec forbids; autostart mechanism documented |
| VM disk fills host | 12G qcow2 + 10G gate; harness in `$STATE/vm`, `--keep` optional |
| worker script bugs reach host | G1–G4 before commit; container gate is mutation sandbox |