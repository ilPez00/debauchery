# Plan — Arch Distrobox (air)

> Companion to `PLAN.md` (Omarchy integration) and `MIGRATION-niri-to-hyprland.md`.
> Status: container creation in progress at the time of writing.

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
| Container | `arch-omarchy`, image `quay.io/toolbx/arch-toolbox:latest`, home `~/.local/share/distrobox/arch-omarchy-home` |
| Disk | 23 GB free (enough; the first attempt failed at 1.4 GB) |

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
  --image quay.io/toolbx/arch-toolbox:latest \
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

## 8. Phase 4 — AUR

Inside the container, install an AUR helper once:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru
makepkg -si
```

Then:

```bash
paru -S <pkg>
```

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

## 12. Safety

- Distrobox is for **tools**, never for the compositor or system services.
- Keep the container home separate.
- Do not `distrobox export` system-level binaries (e.g. `systemctl`, `apt`).
- Removing the container does not remove anything installed via `apt` on Debian.
