#!/bin/bash
# 03 — Create and provision the Arch Distrobox (tools container).
#
# Fixes two known blockers:
#   1. quay.io/toolbx/arch-toolbox is a schema1 manifest podman can no longer
#      pull → uses quay.io/archlinux/archlinux instead.
#   2. the container user has no sudo rights → installs a passwordless-sudo
#      drop-in inside the container (needs root on the host).
#
# Usage: ./03-arch-distrobox.sh [name] [image]
set -euo pipefail

NAME=${1:-arch-omarchy}
IMAGE=${2:-quay.io/archlinux/archlinux:latest}
HOME_DIR=$HOME/.local/share/distrobox/${NAME}-home

command -v distrobox >/dev/null 2>&1 || {
    echo "distrobox not found — run: sudo apt install -y distrobox podman" >&2
    exit 1
}

mkdir -p "$HOME_DIR"

if distrobox list 2>/dev/null | grep -q "| $NAME "; then
    echo "container $NAME already exists — skipping create."
else
    # --pull: without it distrobox prompts and aborts non-interactively.
    distrobox create --pull --name "$NAME" --image "$IMAGE" --home "$HOME_DIR"
fi

echo
echo "== fixing container sudo (needs host root) =="
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    podman exec "$NAME" bash -c '
        mkdir -p /etc/sudoers.d
        echo "gio ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/gio
        chmod 440 /etc/sudoers.d/gio
        visudo -c
    '
    echo "sudoers drop-in installed."
else
    echo "Run this once (needs your password):"
    echo "  sudo podman exec $NAME bash -c 'mkdir -p /etc/sudoers.d && echo \"gio ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/gio && chmod 440 /etc/sudoers.d/gio'"
fi

echo
echo "== provisioning toolchain =="
distrobox enter "$NAME" -- bash -c '
set -e
sudo pacman-key --init >/dev/null 2>&1 || true
sudo pacman-key --populate archlinux >/dev/null 2>&1 || true
sudo pacman -Sy --noconfirm archlinux-keyring >/dev/null 2>&1 || true
sudo pacman -Su --noconfirm >/dev/null 2>&1 || true
sudo pacman -S --noconfirm --needed git base-devel neovim lazygit btop yazi fzf ripgrep fd bat zoxide
for t in git lazygit btop yazi fzf rg fd bat zoxide nvim; do
    printf "%s=%s " "$t" "$(command -v $t >/dev/null && echo ok || echo MISSING)"
done; echo
'

echo
echo "Done. Enter with: distrobox enter $NAME"
