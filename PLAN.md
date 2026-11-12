# Omarchy Integration Plan — air

> **Host:** air — MacBookAir7,2 (MacBook Air 2016), Intel Core i5-5350U, Intel HD Graphics 6000
> **Base:** Debian 13.7 (trixie), kernel 7.2.12+deb13-amd64
> **Desktop today:** niri 26.04 + DMS (Dux Modular Shell) 2.1.2db1, display manager ly
> **Status:** proposal — nothing has been applied. Every phase is reversible.
> **Last updated:** 2026-11-12

---

## 1. Purpose

This document plans how to bring the Omarchy desktop experience to air without
breaking the existing niri + DMS setup, and how to add an Arch Distrobox for
Arch/AUR-only tooling. It also covers the Physis `adapters/omarchy` integration.

It is a plan, not a record of applied changes. Every system-level step is flagged
`[SYSTEM]`; everything else is user-scoped and reversible by deletion.

---

## 2. Executive summary

- **air already runs a Quickshell shell.** DMS (Dux Modular Shell) is a
  Quickshell-based, compositor-agnostic desktop shell — the same technology and
  design lineage as Omarchy 4's "Quattro" shell, and it already runs on niri.
  It provides the bar, menu, launcher, notifications, OSDs, control panels and a
  plugin registry (411 plugins, compositor-agnostic). Replacing it with upstream
  Omarchy's shell is optional and, on niri, a side-grade at best.
- **The genuinely additive, low-risk pieces** are:
  1. an **Arch Distrobox** for Arch/AUR-only tools (Phase 1);
  2. **Omarchy themes / wallpapers / dotfiles** imported into DMS (Phase 2);
  3. the **Physis omarchy adapter**, once a Hyprland session exists (Phase 5).
- **The high-effort, higher-risk piece** is installing Hyprland plus an
  Omarchy-on-Debian port kit (Phase 3–4). These kits modify system files
  (`/etc/pam.d`, `xdg-desktop-portal` masking, `wpaperd`) and are small,
  unofficial, and sometimes stale. Treat them as an **optional second session**,
  review-gated, never applied blind.
- **Recommendation:** do Phase 0 → Phase 1 → Phase 2 first. Defer Phase 3–5 until
  you decide you actually want the upstream Omarchy shell on a separate Hyprland
  session; the Physis adapter only makes sense once that session exists.

---

## 3. Current state of air (verified 2026-11-12)

| Component | State |
|---|---|
| Machine | Apple MacBookAir7,2 (2016), Intel i5-5350U @ 2.90 GHz, Intel HD 6000 |
| OS | Debian 13.7 (trixie), kernel 7.2.12+deb13-amd64 |
| Compositor | niri 26.04 (`niri-session`, systemd user service `niri.service`) |
| Shell | DMS 2.1.2db1 (`dms run --session`), Quickshell 0.3.2 |
| Quickshell source | `https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13` (third-party repo, already trusted) |
| Display manager | ly (`/etc/ly/config.lua`, `waylandsessions = "/usr/share/wayland-sessions"`) |
| Wayland sessions | `niri.desktop`, `niri-duks.desktop`, `niri-noctalia.desktop` |
| DMS theme | `currentThemeName: chadracula`, `matugenScheme: scheme-tonal-spot`, font `MesloLGS NF` |
| DMS plugins | 15 installed (dankMenu, niriWorkspaceBar, clipboardPlus, dankscale, displayModes, storageMonitor, dankKDEConnect, …) |
| Hyprland | **not installed** — candidate `0.55.2+ds-1~bpo13+1` in `trixie-backports` |
| hyprctl | missing |
| Waybar / Fuzzel | missing (not needed for DMS) |
| quickshell | 0.3.2 installed |
| distrobox / podman | **not installed** — `distrobox 1.8.1.2-1`, `podman 5.4.2+ds1-2+b2` in `trixie` main |
| cargo / rustc | **missing** (needed for the Physis adapter and `wpaperd`) |
| Backports | `/etc/apt/sources.list.d/trixie-backports.list` present (`main contrib non-free-firmware`) |
| physis | installed (`~/.local/bin/physis`); adapter source at `~/dev/physis-next/adapters/omarchy` (v1.8.8) |
| Omarchy leftovers | `~/.local/state/omarchy-debian/install.log` (dry-run only); no Omarchy packages, no `~/.local/share/omarchy` |

---

## 4. What Omarchy is, and what is portable

### 4.1 Omarchy v4 "Quattro"

Omarchy (by DHH / 37signals, MIT) is an opinionated Arch-based distro. Its v4
"Quattro" release reimagined the **entire desktop shell in Quickshell**: bar,
launcher, menus, notifications, OSDs, control panels, lock screen and polkit
agent, all in one long-running shell process with a plugin architecture
(`omarchy plugin add <git>`), plus ~90 `omarchy-*` bash scripts, themes (Tokyo
Night, Dracula, Catppuccin, Nord, Solitude, Last Horizon, Lupine, …),
wallpapers, and a unified menu on `Super+Space`.

What is *not* Omarchy: the Arch packaging. The shell is ~2 MB of QML/JS that
shells out to scripts; that is portable. The Arch session tooling, package set,
AUR packages and the boot stack are not.

### 4.2 DMS vs the Omarchy shell

DMS (Dux Modular Shell, by Dux Labs) is a separate Quickshell shell that shares
the Omarchy lineage but is modular, compositor-agnostic and shipped as a Debian
package with a plugin registry. It is the shell air already runs. Differences
that matter here:

| | Omarchy 4 shell | DMS |
|---|---|---|
| Compositor | Hyprland only (patches `hyprctl`, Hyprland window rules) | Any Wayland (niri, Hyprland, …) |
| Bar/launcher | Omarchy Quickshell plugins | DMS `dankbar` / `spotlight` / `dankMenu` |
| Plugins | `omarchy plugin add` (Omarchy-specific) | `dms plugins` (411 in registry, "Compositors: any") |
| Themes | Omarchy theme set + `omarchy-*` CLI | Base16 / matugen (`dms dank16`, `dms matugen`) |
| On air | Would require Hyprland + a port kit | Already running |

**Implication:** DMS already covers most of the "Omarchy look and feel" on niri.
The remaining Omarchy-specific value is (a) upstream themes/wallpapers/scripts,
(b) the Arch-only AUR tooling, and (c) the Physis adapter.

### 4.3 Arch-bound vs portable

| Portable to Debian | Arch-bound (needs Arch / Distrobox) |
|---|---|
| Quickshell shell (QML/JS) | `pacman`, `yay`, AUR packages |
| `omarchy-*` bash scripts (many) | `aether` (lock screen), `herdr` (job runner), `tensaku`, `ttfx`, `tobi-try` |
| Themes, wallpapers, fonts, dotfiles | `omarchy-nvim`, `linux-omarchy` kernel |
| Neovim/fastfetch/btop configs | `omarchy-pkg-*` pickers (rewritten for apt by the port kits) |
| Quickshell plugins | Anything AUR-only |

---

## 5. Options inventory

### Option A — LeisureLinux/omarchy-on-debian

**What:** a numbered, idempotent port kit that runs the Omarchy 4 Quickshell
shell on Debian 13 + Hyprland. Not a distro; a gap-filler.
**URL:** https://github.com/LeisureLinux/omarchy-on-debian
**Maturity:** 6 stars, created 2026-09-05, last push 2026-09-07. Single
maintainer. Tested on Debian 13.6 / Hyprland 0.55.2 / Quickshell 0.3.0 / Qt 6.8.2.
**Shape:** `preflight.sh`, `install.sh [--dry-run] [--only N]`, and
`steps/10-deps.sh` … `steps/74-workspace-wallpaper.sh`.

Key steps:

| Step | What | Scope |
|---|---|---|
| 10 | apt deps; trixie-backports pinned to 100; Nerd Font download | `[SYSTEM]` |
| 20 | clone Omarchy `--branch quattro` | user |
| 30 | rsync `shell/ bin/ config/ default/ themes/` → `~/.local/share/omarchy` | user |
| 40 | compatibility patches (idempotent, reversible) | user |
| 50 | `omarchy.ttf`, monospace → Nerd Font | user |
| 60 | Hyprland autostart, menu key, window rules | user |
| 65 | About screen, `/etc/fastfetch/config.jsonc`, xdg-terminal-exec glue | `[SYSTEM]` |
| 66 | `omacalc` via rofi + qalc | user |
| 67 | patch `omarchy-hyprland-monitor-scaling` for `hyprctl keyword monitor` | user |
| 68 | rewrite `omarchy-pkg-*` pickers against apt | user |
| 70 | pin Quickshell bar to `WlrLayer.Overlay` | user |
| 71 | health check script | user |
| 72 | `/etc/pam.d/omarchy-lock-password` for the Quickshell lock plugin | `[SYSTEM]` |
| 73 | `wpaperd` via `cargo install`; `~/Pictures/wallpapers/` | user |
| 74 | per-workspace wallpapers; **masks `xdg-desktop-portal-hyprland.service`**; replaces `/etc/pam.d/hyprlock` | `[SYSTEM]` (risky) |

**Pros:** real Omarchy 4 Quickshell shell; numbered/reviewable; dry-run and
preflight; backups under `~/.local/share/omarchy/.omarchy-on-debian/backups/`.
**Cons:** small and stale; `[SYSTEM]` steps 65/72/74 (PAM, portal mask) are the
kind of thing that quietly breaks screencopy/screen-share and lock; step 73/74
need cargo; Hyprland-only (does not use niri).

### Option B — alfonsocvu/omarchy (`debian-version` branch)

**What:** a full fork of the Omarchy repo with a Debian POC — makes Omarchy's own
`boot.sh` / `install.sh` run on Debian. Not a port kit; a fork.
**URL:** https://github.com/alfonsocvu/omarchy/tree/debian-version
**Maturity:** POC, "horrible" in the author's own words; branches
`debian-version`, `debian-utm-version`, `dev`.
**Relevant files:** `install/post-install/apt.sh`, `install/preflight/apt.sh`,
`boot.sh`, plus a full Omarchy tree.
**Verdict:** **not recommended.** It carries the whole Arch-centric Omarchy
tree and its install machinery; it is harder to review and to keep up to date
than Option A. The discussion that spawned it
(https://github.com/omacom/omarchy/discussions/5042) concluded a Debian base is a
poor fit and pointed at Ubuntu/omakub instead. Superseded by A/C/D.

### Option C — CommunityPokeOrg/omarchy-debian

**What:** the installer air already dry-ran. It maps Omarchy's package list onto
Debian packages/external builds/manual steps, then clones upstream Omarchy.
**URL:** https://github.com/CommunityPokeOrg/omarchy-debian (cloned via zsh history)
**Evidence on disk:** `~/.local/state/omarchy-debian/install.log` (dry-run,
2026-11-03). Phases: 00-preflight, 10-apt-deps, 20-external, 30-upstream,
40-desktop, 45-hardware, 50-dotfiles, 60-services, 70-finish. Docs referenced:
`docs/MAPPING.md`, `docs/MANUAL-STEPS.md`, `docs/LIMITATIONS.md`.
**Notable from the log:**
- `distro: debian 13 (trixie) — support: supported-backports`
- Hyprland stack from trixie-backports; `quickshell` "needs a source build; the
  overlay ships a **waybar fallback**"
- non-apt entries are classified `[skip]`/`[manual]`/`[external]`
- `45-hardware.sh` **failed** (status 1) even in dry-run; needs re-running
- clones `omacom/omarchy@9c5482c` → `~/.local/share/omarchy`
- `sudo authentication failed` on the first attempt (the installer wants root)

**Verdict:** the most "Debian-native" of the port kits and the one air already
tried. It pairs with the Physis adapter (which targets its Waybar/Fuzzel shell).
But it installs **Waybar + Fuzzel**, not the Quickshell shell — i.e. the older
Omarchy 3-style shell, not Quattro. If the goal is Omarchy 4's Quickshell UI,
Option A is the better match.

### Option D — kaiseki

**What:** "Omarchy's desktop on Debian" — a serious port: upstream pinned,
`map/arch-to-debian.tsv`, 24 Arch recipes wrapped as `.deb`, shims for
`pacman`/`yay`/`snapper`/`cryptsetup`, an installer ISO on encrypted ZFS, and a
signed apt repository.
**URL:** https://github.com/0x64616e6e/kaiseki — https://kaiseki.este.systems/
**Maturity:** works in test VMs (2026-10-06), one real-hardware install; Debian
**testing** base (Debian 13 needs six packages rebuilt from unstable).
**Verdict:** the highest-quality port, but it is a **full desktop replacement**
(a new OS install / ISO). Not an integration path for a working air. Reference
for how a clean port should be structured.

### Option E — omaxian

**What:** the Omarchy **shell** ported to Debian-family on **X11 / XLibre + i3**
(no Wayland, no Hyprland).
**URL:** https://omaxian.org/shell
**Verdict:** **not applicable** — air is Wayland/niri. Ignore unless an X11 i3
session is ever wanted.

### Option F — basedlinux.com "Pure Omarchy Trixie"

**What:** a packaged Omarchy on Debian 13 as an installable ISO (their packaging,
not an Omarchy release).
**URL:** https://basedlinux.com/editions/pure-omarchy-trixie/
**Verdict:** a prebuilt ISO route (like D). Not an integration path; also a
third-party rebuild to trust.

### Option G — DMS native (no Hyprland)

**What:** stay on niri + DMS and import only the portable Omarchy assets:
themes (Tokyo Night / Dracula / Catppuccin / Nord …), wallpapers, fonts,
`omarchy-*` scripts that are portable, and DMS plugins from the registry.
**Pros:** zero compositor change; zero system changes; fully reversible;
immediate. **Cons:** not the literal upstream Omarchy shell.

### Comparison

| Option | Shell | Hyprland | System changes | Maturity | Verdict |
|---|---|---|---|---|---|
| A LeisureLinux | Omarchy 4 Quickshell | yes | PAM, portal mask, wpaperd | low (6★, stale) | **optional second session, review-gated** |
| B alfonsocvu | Omarchy (fork) | yes | full fork | POC | skip |
| C CommunityPokeOrg | Waybar + Fuzzel fallback | yes | apt + overlay | low/medium | **pairs with Physis adapter; already triaged** |
| D kaiseki | Omarchy 4 Quickshell | yes | full OS | medium | reference only (new install) |
| E omaxian | Omarchy shell on X11/i3 | no | X11 stack | low | not applicable |
| F basedlinux | Omarchy 4 | yes | full OS (ISO) | medium | not an integration path |
| G DMS native | DMS Quickshell | no | none | shipped | **do this first** |

---

## 6. Recommended architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ air — Debian 13.7 (kernel, systemd, apt, drivers, SSH, Tailscale) │
│                                                                  │
│  Session 1 (default):  niri  + DMS (Quickshell)                  │
│      └─ Physis HUD / notebook / agents (already installed)       │
│                                                                  │
│  Session 2 (optional): Hyprland + Omarchy 4 Quickshell shell     │
│      └─ port kit (Option A) — only if you want the literal UI    │
│                                                                  │
│  Execution environment (both sessions):  Arch Distrobox          │
│      └─ AUR/arch-only tools, not the compositor, not services    │
└──────────────────────────────────────────────────────────────────┘
```

**Principles**

1. Debian owns the system: kernel, boot, packing (`apt`), systemd, drivers,
   SSH, Tailscale, Physis.
2. The compositor is a session choice, not a migration: niri stays the default;
   Hyprland is an additional ly session.
3. Distrobox supplies **applications and toolchains**, never the display
   session and never system services.
4. Prefer portable assets (themes, scripts, dotfiles) over port kits; prefer
   port kits over forked distros.
5. No blind `sudo`. Every `[SYSTEM]` step is reviewed before it runs.

---

## 7. Physis integration (`adapters/omarchy`)

### 7.1 What exists (local checkout v1.8.8)

A separate Rust crate at `~/dev/physis-next/adapters/omarchy` (not a member of
the engine workspace). It observes a Hyprland desktop into the Physis world and
exposes typed operations over a Unix socket.

- **Evidence sources:** Hyprland IPC socket2 events, `hyprctl -j`, `/proc/<pid>/{exe,cwd,comm}`, `.git` walk.
- **Objects:** `workspace → window ← process → file`, plus `app:<class> → dir:<repo>`.
- **Operations:** `focus_window`, `switch_workspace`, `open_file`, `open_folder`, `open_terminal`, `inspect_repository`, `pin_to_notebook`, `query_relations`, `close_window` (destructive, requires explicit authorization).
- **IPC:** `$XDG_RUNTIME_DIR/physis-omarchy.sock`, mode 0700, `SO_PEERCRED` peer check, 64 KiB message limit, closed operation enum (no arbitrary shell execution).
- **Shortcuts:** `SUPER+SHIFT+P` inspect, `SUPER+SHIFT+H` HUD, `SUPER+SHIFT+O` operations.
- **Tests:** engine fold 56, adapter 33, fixtures 6, session/IPC 7, installer dry-run/idempotence/uninstall pass, daemon-without-compositor pass. Graphical-session smoke test **UNVERIFIED**.

### 7.2 Mismatches to resolve before deployment

1. **Shell mismatch.** The adapter targets **Hyprland + Waybar + Fuzzel** (the
   CommunityPokeOrg/omarchy-debian shell). It does **not** target Quickshell and
   does **not** target DMS. If air keeps niri + DMS, the adapter's Waybar module
   and Fuzzel integration are dead weight; the observer and typed operations are
   shell-independent, but the bar/launcher surface would need adapting.
2. **Compositor mismatch.** The adapter requires `hyprctl`. On niri it cannot
   observe anything. Deploying it therefore *presupposes* a Hyprland session.
3. **`~/.config/hypr/extra.conf` sourcing.** The installer appends
   `source = ~/.config/hypr/physis-omarchy.conf` to `extra.conf`, which is
   sourced by Hyprland's `hyprland.conf`. If a port kit builds a config that
   does not source `extra.conf`, the shortcuts never activate. Verify after
   Phase 3/4.
4. **Engine dependency.** The installer reuses `~/.local/bin/physis` if present
   and builds only the adapter crate. `cargo` is currently **missing** on air.

### 7.3 Installer bug (confirmed)

The adapter `README.md` documents `./install.sh --dry-run`, but the script
implements only the environment variable:

```
DRY_RUN=${OMARCHY_DEBIAN_DRY_RUN:-0}
```

`./install.sh --dry-run` is therefore **not** a dry run — it would deploy. The
correct invocation is:

```
cd ~/dev/physis-next
OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh
```

Recommend fixing the installer to accept `--dry-run` as well (one-line:
`case "$1" in --dry-run) DRY_RUN=1;; esac` before the env default), then
re-testing the dry-run path.

### 7.4 Next steps

1. Fix the `--dry-run` parsing bug; re-run the dry-run.
2. Decide the shell target (DMS vs upstream Quickshell). If DMS: plan a small
   adaptation (DMS already has an IPC surface; a `dms` observer could replace
   the Waybar module). If upstream Quickshell: deploy the adapter only after
   Phase 3/4 produce a Hyprland session.
3. Install Rust (`rustup` or Debian `cargo`/`rustc`) — needed for the adapter
   and for the port kit's `wpaperd` step.
4. Run the adapter test suite before any live deployment:
   `cargo test --manifest-path adapters/omarchy/Cargo.toml` and
   `./adapters/omarchy/demo.sh --mock`.
5. Deploy with `install.sh`, restart the Hyprland session, verify
   `SUPER+SHIFT+P`.

---

## 8. Implementation phases

### Phase 0 — Backups and safety `[user]`

```bash
mkdir -p ~/debauchery/backups/2026-11-12
for app in niri dms hypr quickshell waybar fuzzel ly; do
  [ -e "$HOME/.config/$app" ] && cp -a "$HOME/.config/$app" ~/debauchery/backups/2026-11-12/
done
cp -a ~/.local/share/applications ~/debauchery/backups/2026-11-12/ 2>/dev/null
cp -a ~/.config/systemd/user ~/debauchery/backups/2026-11-12/systemd-user 2>/dev/null
```

Also record the current session inventory:

```bash
ls /usr/share/wayland-sessions/ > ~/debauchery/backups/2026-11-12/sessions-before.txt
dpkg -l | grep -Ei 'niri|dms|quickshell|hyprland' > ~/debauchery/backups/2026-11-12/pkgs-before.txt
```

### Phase 1 — Arch Distrobox `[system + user]` (recommended first)

```bash
sudo apt update
sudo apt install -y distrobox podman
```

Rootless podman on Debian needs subuids/subgids for the user. If
`podman` complains:

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 gio
```

(requires re-login; alternatively run podman rootful, which distrobox supports
but discourages).

Create the container with a **separate home** to avoid dotfile clashes:

```bash
mkdir -p ~/.local/share/distrobox/arch-omarchy-home
distrobox create \
  --name arch-omarchy \
  --image quay.io/toolbx/arch-toolbox:latest \
  --home "$HOME/.local/share/distrobox/arch-omarchy-home"
```

Use it:

```bash
distrobox enter arch-omarchy
sudo pacman -Syu
sudo pacman -S --needed git base-devel neovim lazygit btop yazi fzf ripgrep fd bat zoxide
# from the host:
distrobox enter arch-omarchy -- lazygit
```

Notes:
- This is a container for **tools**, not a security boundary; it integrates
  closely with the host (shared home is optional, shared UID, host D-Bus).
- GUI apps can be exported, but prefer native Debian packages where they exist.
- This phase is independent of the compositor and can be done immediately.

### Phase 2 — Omarchy themes / wallpapers / dotfiles into DMS `[user]`

Low risk, high visible payoff.

1. Wallpapers: download Omarchy's wallpaper set into `~/Pictures/wallpapers/`
   and point DMS at the directory (DMS manages wallpaper itself).
2. Themes: DMS supports Base16/matugen. Either
   - `dms dank16` to generate a Base16 palette from a wallpaper, or
   - import an Omarchy theme's Base16 palette into DMS (`currentThemeName` /
     `matugenScheme` in `~/.config/dms/settings.json`).
   Candidate upstream themes: Tokyo Night, Dracula, Catppuccin, Nord.
3. Fonts: Omarchy ships `omarchy.ttf` and uses Nerd Fonts; DMS's font is set by
   `fontFamily` (currently `MesloLGS NF`). Install the desired Nerd Font and
   set `fontFamily`.
4. Dotfiles: Omarchy's `default/` and `config/` trees contain portable neovim,
   fastfetch, btop, kitty/foot/alacritty configs. Copy selectively; never
   overwrite an existing config without a `.pre-omarchy` backup.
5. Scripts: many `omarchy-*` bash scripts are portable. Copy the ones you want
   into `~/.local/bin`, check their dependencies (`pactl`, `brightnessctl`,
   `playerctl`, `nmcli`, …) and keep the Arch-only ones for the Distrobox.

### Phase 3 — Hyprland session `[system + user]` (optional)

```bash
sudo apt install -t trixie-backports hyprland hyprlock hypridle hyprpaper \
  xdg-desktop-portal-hyprland uwsm
```

Then add a ly session entry (`/usr/share/wayland-sessions/hyprland.desktop`)
and verify that logging into Hyprland works **before** adding any Omarchy layer.
Keep niri as the default session; choose Hyprland from ly's session list.

Verify: `hyprctl clients`, `hyprctl monitors`, `hyprctl systeminfo`, and that
`xdg-desktop-portal-hyprland` is **not** masked.

### Phase 4 — Omarchy shell via a port kit `[system + user]` (optional)

Two sub-options:

- **Option A (Quattro/Quickshell, matches "Omarchy 4"):**
  ```bash
  git clone https://github.com/LeisureLinux/omarchy-on-debian
  cd omarchy-on-debian
  ./preflight.sh            # shows the sudo-vs-user split
  ./install.sh --dry-run    # prints every command
  ./install.sh --only 40    # re-apply patches after an upstream refresh
  ```
  **Review before running:** steps 65 (`/etc/fastfetch`), 72 (`/etc/pam.d`),
  73 (`cargo install wpaperd`), 74 (masks `xdg-desktop-portal-hyprland.service`
  and replaces `/etc/pam.d/hyprlock`). Step 74 is the one that has broken
  screencopy/screen-share for people; decide consciously whether to run it.
- **Option C (Waybar/Fuzzel, pairs with the Physis adapter):** run the
  CommunityPokeOrg installer, re-running the failed `45-hardware.sh` phase.

Install Rust first (needed by both the kit's `wpaperd` step and the Physis
adapter):

```bash
sudo apt install -y cargo rustc        # or rustup for a current toolchain
```

### Phase 5 — Physis adapter `[user]`

Prerequisites: Hyprland installed, `hyprctl` present, `cargo` present, and
`~/.config/hypr/extra.conf` sourced by the Hyprland config.

```bash
cd ~/dev/physis-next
cargo test   --manifest-path adapters/omarchy/Cargo.toml
./adapters/omarchy/demo.sh --mock
OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh   # verify the dry run first
./adapters/omarchy/install.sh
systemctl --user daemon-reload && systemctl --user restart physis-omarchy
```

Then, in the Hyprland session: `SUPER+SHIFT+P` (inspect), `SUPER+SHIFT+H`
(HUD), `SUPER+SHIFT+O` (operations). Revert with `./uninstall.sh`.

### Phase 6 — Verification

- [ ] niri session still boots and DMS works (default session unchanged).
- [ ] Hyprland session appears in ly and boots (if Phase 3 done).
- [ ] Omarchy menu opens on `Super+Space` (if Phase 4 done).
- [ ] `distrobox list` shows `arch-omarchy`; `distrobox enter arch-omarchy -- uname -a` reports Arch.
- [ ] `hyprctl systeminfo` works; `xdg-desktop-portal-hyprland` not masked.
- [ ] Physis: `physis-omarchy inspect` resolves the active window; the socket
      exists at `$XDG_RUNTIME_DIR/physis-omarchy.sock`.
- [ ] No unexpected changes to `/etc/pam.d`, `/etc/fastfetch`, or portal units
      (compare against `~/debauchery/backups/`).

---

## 9. Guidelines and safety rules

1. **Reversibility first.** Every change has a documented undo: user files are
   backed up (`.pre-omarchy` or `~/debauchery/backups/`), system packages are
   removable, port kits ship `--only N` re-application and backups.
2. **No blind sudo.** Read every `[SYSTEM]` step before running it. Prefer
   `preflight.sh` / `--dry-run` / `--only N` over a full `./install.sh`.
3. **One shell at a time.** DMS and the Omarchy Quickshell shell both register
   notifications/tray; do not run them in the same session. If you install the
   Omarchy shell on Hyprland, keep DMS disabled there.
4. **Do not replace the default session.** niri stays the ly default; Hyprland
   is an opt-in session. This keeps a known-good fallback one logout away.
5. **Distrobox is for tools, not the session.** Never put the compositor, a
   display portal, or a systemd system service inside the container.
6. **Separate container home.** Use `~/.local/share/distrobox/<name>-home` to
   avoid clobbering Debian dotfiles.
7. **Review before trusting.** Small unofficial kits can be excellent, but read
   the steps that touch `/etc`, PAM, portals, and package masking.
8. **Keep a written record.** Log every applied phase and its outcome in this
   repository (`notes/`), including anything that failed and why.

---

## 10. Risks and caveats

| Risk | Impact | Mitigation |
|---|---|---|
| Port kit masks `xdg-desktop-portal-hyprland.service` (step 74) | screen capture / screen share breaks | review step 74; run it last; unmask and test |
| Port kit replaces `/etc/pam.d/hyprlock` (step 74) | lock screen auth breaks | back up `/etc/pam.d/hyprlock`; test lock before/after |
| Port kit adds `/etc/pam.d/omarchy-lock-password` (step 72) | PAM misconfig | back up `/etc/pam.d`; keep a root shell open while testing |
| `cargo install wpaperd` (step 73) | long build, proxy issues | use `NO_PROXY=*`; or skip and use `hyprpaper` |
| Hyprland + niri both installed | session confusion | niri default; Hyprland opt-in; label ly entries |
| DMS and Omarchy shell both active | notification/tray conflicts | enable exactly one per session |
| Distrobox rootless subuid missing | `podman` fails | add subuids (root) or run rootful |
| Physis adapter assumes Waybar/Fuzzel | dead integration on DMS | adapt the adapter or use Option C's shell |
| `install.sh --dry-run` is broken (adapter) | accidental deployment | use `OMARCHY_DEBIAN_DRY_RUN=1`; fix the flag |
| Third-party repos (danklinux opensuse, port kits) | supply-chain trust | keep them explicit; pin what you rely on |
| MacBook Air 2016 hardware | GPU/input quirks | Intel HD 6000 is well supported; test input/backlight/brightness keys early |

---

## 11. Resources

**Upstream / reference**
- Omarchy (GitHub, MIT): https://github.com/omacom/omarchy — manual in `manual/`
- Omarchy site / releases: https://omarchy.org — ISOs at https://iso.omarchy.org
- Omarchy manual (welcome): https://github.com/basecamp/omarchy/blob/quattro/manual/01-welcome-to-omarchy.md
- Hyprland wiki (IPC, sockets): https://wiki.hypr.land
- Distrobox: https://github.com/89luca89/distrobox — Arch toolbox image: `quay.io/toolbx/arch-toolbox:latest`
- Toolbx Arch image: https://quay.io/repository/toolbx/arch-toolbox

**Port kits / Debian projects**
- LeisureLinux/omarchy-on-debian: https://github.com/LeisureLinux/omarchy-on-debian
- CommunityPokeOrg/omarchy-debian: https://github.com/CommunityPokeOrg/omarchy-debian
- alfonsocvu/omarchy `debian-version`: https://github.com/alfonsocvu/omarchy/tree/debian-version
- kaiseki (Omarchy on Debian, ISO + apt repo): https://github.com/0x64616e6e/kaiseki — https://kaiseki.este.systems/
- omaxian (X11/i3 shell port): https://omaxian.org/shell
- basedlinux Pure Omarchy Trixie ISO: https://basedlinux.com/editions/pure-omarchy-trixie/
- Omarchy Debian discussion (#5042): https://github.com/omacom/omarchy/discussions/5042

**DMS (already installed)**
- DMS package: `dms 2.1.2db1`; plugin/theme CLI: `dms plugins`, `dms registry`, `dms dank16`, `dms matugen`
- DMS plugin registry (411 plugins): `dms plugins browse`
- Quickshell: https://github.com/quickshell-mirror/quickshell

**Physis**
- Adapter source: `~/dev/physis-next/adapters/omarchy` (v1.8.8)
- Adapter README: `~/dev/physis-next/adapters/omarchy/README.md`
- Engine crates used: `crates/physis-kernel`, `physis-store`, `physis-query`, `physis-notebook`

**Debian / packages**
- trixie-backports: http://deb.debian.org/debian trixie-backports
- `apt-cache policy hyprland quickshell distrobox podman`

---

## 12. Open decisions

1. **Do you want the literal Omarchy 4 Quickshell shell on a second (Hyprland)
   session, or is DMS enough?** (Affects whether Phase 3–4 happen at all.)
2. **If yes, Option A (Quickshell) or Option C (Waybar/Fuzzel + Physis adapter)?**
3. **Run port-kit step 74 (portal mask / hyprlock PAM) or skip it?** Recommend
   skip initially; add later only if per-workspace wallpapers are wanted.
4. **Fix the adapter `--dry-run` bug now?** (small, safe, improves safety)
5. **Distrobox image:** `quay.io/toolbx/arch-toolbox:latest` (toolbx, recommended)
   vs `docker.io/library/archlinux:latest` (plain Arch)?
6. **Subuid allocation for rootless podman** — OK to run the `usermod` (root) step?
7. **Which Omarchy themes/wallpapers** to import into DMS first?

---

## 13. Verification log

| Date | Phase | Action | Outcome |
|---|---|---|---|
| 2026-11-12 | 0 (plan) | Investigated options, verified host state, wrote this plan | done — nothing applied |
| 2026-11-12 | 1 | Arch Distrobox `arch-omarchy` created, toolchain installed | done |
| 2026-11-12 | 3 | Hyprland 0.55.2 installed, config written, `--verify-config` ok | done; live login pending |
| 2026-11-12 | 5 | Adapter `--dry-run` bug fixed; tests + `demo.sh --mock` pass; adapter deployed; `$mainMod` defined; HUD rebound to `SUPER+SHIFT G` | done; graphical smoke test pending |
| 2026-11-03 | — | `omarchy-debian` dry-run (pre-existing) | phase `45-hardware.sh` failed; no changes |

---

## Appendix A — Command cheat-sheet

```bash
# host facts
cat /sys/class/dmi/id/product_name
apt-cache policy hyprland quickshell distrobox podman
ls /usr/share/wayland-sessions/

# distrobox
distrobox list
distrobox enter arch-omarchy
distrobox enter arch-omarchy -- <cmd>

# dms
dms plugins list
dms plugins browse
dms registry
dms dank16
dms matugen

# niri
niri validate
niri msg action load-config-file

# physis adapter
cd ~/dev/physis-next
cargo test --manifest-path adapters/omarchy/Cargo.toml
./adapters/omarchy/demo.sh --mock
OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh

# omarchy port kit (Option A)
./preflight.sh
./install.sh --dry-run
./install.sh --only 40
```
