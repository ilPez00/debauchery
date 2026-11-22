# Plan — Arch Distrobox (air)

> Companion to `PLAN.md` (Omarchy integration) and `MIGRATION-niri-to-hyprland.md`.
> Status: **live and in use** since 2026-11-12 (see §2). Reach it with
> `omarchy-arch`, `omarchy-arch --status`, `omarchy-arch --os`.

## 1. Purpose

Give air an **Arch Linux execution environment** for Arch-only / AUR tooling,
without touching the Debian base. The compositor, display portals, systemd
services and kernel stay on Debian. The container is for **applications and
toolchains only**.

## 2. Current status (verified)

| | |
|---|---|
| distrobox | 1.8.1.2-1 (trixie) |
| podman | 5.4.2+ds1-2+b2 (trixie), rootless |
| Subuids | `gio:100000:65536` in `/etc/subuid` + `/etc/subgid` |
| Container | `arch-omarchy` — **created 2026-11-12**, image `quay.io/archlinux/archlinux:latest`, home `~/.local/share/distrobox/arch-omarchy-home` |
| Image note | `quay.io/toolbx/arch-toolbox:latest` is a **schema1** manifest (podman cannot pull it — hangs at 0 bytes); `quay.io/toolbx-images/...` returns UNAUTHORIZED. Use `quay.io/archlinux/archlinux:latest` (OCI v2) or `docker.io/library/archlinux:latest`. |
| Disk | ~21 GB free (enough; the first attempt failed at 1.4 GB) |
| Bridge | `omarchy-arch` / `omarchy-pkg*` / `pacman` shims deployed 2026-11-12 — see §12 |

## 3. Why Distrobox (and not a VM / chroot)

- **No virtualization layer**: the container shares the kernel and the user's
  UID; GUI apps can reach the host Wayland socket.
- **App export**: `distrobox-export` puts container binaries on the host PATH and
  creates `.desktop` entries, so a container app behaves like a native one.
- **Reversible**: delete the container and its home; nothing else changes.
- **Not a security boundary**: the container is root inside its own namespace but
  maps to your host UID. Treat it as a package manager, not a sandbox.

## 4. Architecture

```
Debian 13 (kernel, systemd, apt, drivers, Wayland, DMS, Physis)
│
├── niri session  → DMS
├── Hyprland session → DMS
│
└── podman (rootless)
     └── arch-omarchy container
          ├── pacman + AUR (paru/yay)
          ├── Arch-only CLI tools
          └── GUI apps exported to the host via distrobox-export
```

## 5. Phase 1 — Create the container

```bash
mkdir -p ~/.local/share/distrobox/arch-omarchy-home
distrobox create --pull \
  --name arch-omarchy \
  --image quay.io/archlinux/archlinux:latest \
  --home "$HOME/.local/share/distrobox/arch-omarchy-home"
```

- `--pull` matters: without it, distrobox prompts for confirmation and aborts
  non-interactively.
- The separate `--home` avoids clobbering Debian dotfiles (`.bashrc`, `.zshrc`,
  `.config`, …).

If rootless podman ever complains about subuids:

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 gio
# then re-login
```

## 6. Phase 2 — Configure

```bash
distrobox enter arch-omarchy
sudo pacman -Syu
sudo pacman -S --needed git base-devel neovim lazygit btop yazi fzf ripgrep fd bat zoxide
```

Optional: a fast mirror. Inside the container:

```bash
sudo pacman -S --needed reflector
sudo reflector --country Italy --age 12 --sort rate --save /etc/pacman.d/mirrorlist
```

## 7. Phase 3 — Daily use

```bash
# interactive shell
distrobox enter arch-omarchy

# run one command from the host
distrobox enter arch-omarchy -- lazygit
distrobox enter arch-omarchy -- yazi

# list / stop / remove
distrobox list
distrobox stop arch-omarchy
distrobox rm arch-omarchy
```

Prefer **native Debian packages** when they exist (`apt`); use the container for
Arch-only tools, AUR packages, and toolchains you want to keep out of Debian.

## 8. Phase 4 — AUR (installed 2026-11-12)

Both helpers are in the container, installed by `omarchy-arch --bootstrap-aur`:

| Helper | Package | Path |
|---|---|---|
| `paru` | `paru-bin` (AUR, prebuilt) | `/usr/bin/paru` |
| `yay` | `yay-bin` (AUR, prebuilt) | `/usr/bin/yay` |

`paru-bin` / `yay-bin` rather than building `paru` `yay` from source: the `-bin`
packages skip a full Rust build, which matters on this dual-core 2015 CPU.
`yay-bin` was installed *through* paru, which is itself the end-to-end proof
that the AUR path works.

Then:

```bash
omarchy-pkg aur-add aether          # explicit AUR install
omarchy-pkg add some-aur-only-pkg   # auto: Debian → Arch repo → AUR
omarchy-arch paru -S <pkg>          # straight through the gateway
omarchy-arch --status               # paru / yay presence
```

### The Omarchy tools themselves

`scripts/10-omarchy-tools.sh` installs every `arch:`/`aur:` tool listed in the
map and exports each binary to `~/.local/bin` with `distrobox-export`, so the
tools are callable from the DMS/Hyprland session without `distrobox enter`.
Package names were checked against the container on 2026-11-12:

| Tool | Target | Note |
|---|---|---|
| `aether` | `aur:` | 4.32.0 — lock screen; pulls a large GTK/WebKit dependency set |
| `herdr` | `aur:` | 0.9.3 — GTK/Rust job runner, long cargo build on 2 cores |
| `impala` | `arch:` | 0.9.0 — in Arch's `extra` repo, **not** the AUR (map corrected) |
| `tensaku` | `aur:` | 0.29.0 |
| `ttfx` | `aur:` | 0.5.1 |
| `omarchy-nvim` | `skip` | not published in the AUR or repos; ships in the Omarchy repo itself |

## 9. Phase 5 — GUI apps from the container

```bash
distrobox enter arch-omarchy
distrobox-export --app <binary>          # creates a host .desktop entry
distrobox-export --bin /usr/bin/<binary> # puts the binary on the host PATH
```

GUI apps reach the host display through the mounted Wayland socket and the host's
`XDG_RUNTIME_DIR`; no extra configuration is normally needed.

## 10. Phase 6 — Teardown

```bash
distrobox stop arch-omarchy
distrobox rm arch-omarchy
podman system prune -f
rm -rf ~/.local/share/distrobox/arch-omarchy-home
```

Nothing on the Debian side is affected.

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Image ... not found. Do you want to pull...?` then exit 1 | missing `--pull` / no TTY | use `distrobox create --pull ...` |
| `no space left on device` while pulling | rootfs full | free space (see `notes/`), then retry |
| `newuidmap: write to uid_map failed` | no subuids | `sudo usermod --add-subuids ...` |
| container app can't reach the display | `XDG_RUNTIME_DIR` / socket not mounted | run the app from inside `distrobox enter` |
| `pacman` keyring errors on first run | uninitialized keyring | `sudo pacman-key --init && sudo pacman-key --populate archlinux` |

## 12. Usage bridge — Arch commands on a Debian base

Omarchy's scripts are `pacman`/`yay`-shaped; air's base is Debian. Instead of
rewriting those scripts, a thin bridge (deployed by
`scripts/08-arch-bridge.sh`) resolves every package operation to the right side
of the wall. Prefer the Debian package; fall back to the container.

| Installed as | What it does |
|---|---|
| `~/.local/bin/omarchy-arch` | gateway: `omarchy-arch <cmd>`, interactive shell, `--status`, `--bootstrap-aur` |
| `pacman`, `yay`, `paru` | symlinks to the gateway; run inside the container |
| `omarchy-pkg` (+ `omarchy-pkg-{add,drop,present,missing,install,remove,aur-add,aur-install}`) | upstream verb names, Debian-first resolution |
| `~/.config/omarchy-bridge/arch-debian.map` | `<arch>  apt:<deb>|arch:<pkg>|aur:<pkg>|skip` |

```bash
omarchy-pkg add fd neovim        # fd → apt:fd-find, neovim → apt
omarchy-pkg add impala           # map says aur: → paru in the container
omarchy-pkg present git jq       # exit 0 only if all present
omarchy-pkg missing git foo      # exit 0 if any is missing (upstream semantics)
omarchy-pkg drop fd              # removes whichever side installed it
OMARCHY_PKG_DRY_RUN=1 omarchy-pkg add bat   # print the plan, change nothing
omarchy-arch --status            # host, container, gateway state
omarchy-arch lazygit             # one-shot container command
```

Notes:

- **Never named `arch`** — that is a Debian coreutils binary; shadowing it would
  break scripts that ask for the machine architecture.
- The container imports the host `PATH`, so the shims are visible *inside* the
  box. The gateway pins `PATH` to the container's own and sets
  `OMARCHY_IN_BOX=1`, which makes a shim invoked in-container exit 127 instead
  of recursing.
- AUR helpers are installed (`paru`, `yay`); `omarchy-arch --bootstrap-aur`
  reproduces that from scratch (paru-bin + yay-bin). A name with no map line
  resolves Debian → Arch repos → AUR, so AUR-only packages do not need a map
  entry.
- Teardown: `./scripts/08-arch-bridge.sh --uninstall` (container untouched).

## 13. Boot ordering — exported services vs. the container

`distrobox-export --bin` puts a shim on the host PATH that calls
`distrobox-enter -n arch-omarchy -- <binary>`. Any user unit whose `ExecStart`
is such a shim depends on the container even though its unit file says nothing
about podman. `herdr.service` is the concrete case: `ExecStart=%h/.local/bin/herdr
server` is a shim, so at boot it raced the container and crash-looped with
`cannot start a container that has stopped`, `NRestarts=58`.

The state behind that error is `Initialized` (created but never successfully
started). `podman start` alone does **not** clear it; `podman container cleanup
<name>` does, and `podman start` then succeeds. The container's home and
packages are untouched — never recreate the box to fix this.

Module `boxboot` (`scripts/17-container-boot.sh`, profiles `arch,all`) installs:

| File | Role |
|---|---|
| `configs/systemd/arch-omarchy-container.service` → `~/.config/systemd/user/` | oneshot, `RemainAfterExit=yes`, enabled at `default.target`; exits 0 if already `running`, otherwise cleans stale state then `podman start arch-omarchy` |
| `configs/systemd/herdr.service.d/10-container.conf` → `~/.config/systemd/user/herdr.service.d/` | `Requires=`/`After=arch-omarchy-container.service` and `StartLimitIntervalSec=300` / `StartLimitBurst=5` so a future breakage fails fast instead of looping |

The drop-in, not an edit of `herdr.service`, is deliberate: re-exporting the
shim rewrites the unit but leaves the drop-in in place.

Deploy and verify:

```bash
./install.sh install --only boxboot
./scripts/17-container-boot.sh --check
systemctl --user show herdr.service -p NRestarts -p ActiveState -p SubState
podman ps -a --format '{{.Names}} {{.Status}}'
```

Want `NRestarts=0`, `active/running`, and the container `Up`. Simulate a reboot
without one: `podman stop arch-omarchy`, `systemctl --user stop
arch-omarchy-container.service`, `systemctl --user restart herdr.service` — the
container must come back on its own.

## 14. Safety

- Distrobox is for **tools**, never for the compositor or system services.
- Keep the container home separate.
- Do not `distrobox export` system-level binaries (e.g. `systemctl`, `apt`).
- Removing the container does not remove anything installed via `apt` on Debian.
