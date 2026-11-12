#!/bin/bash
# Create the Arch Distrobox for Arch/AUR-only tools (PLAN.md Phase 1).
# Usage: create-arch-distrobox.sh [name] [image]
set -euo pipefail

NAME=${1:-arch-omarchy}
IMAGE=${2:-quay.io/toolbx/arch-toolbox:latest}
HOME_DIR=$HOME/.local/share/distrobox/${NAME}-home

command -v distrobox >/dev/null 2>&1 || {
    echo "distrobox not found — run: sudo apt install -y distrobox podman" >&2
    exit 1
}

mkdir -p "$HOME_DIR"
distrobox create --name "$NAME" --image "$IMAGE" --home "$HOME_DIR"
echo "created $NAME; enter with: distrobox enter $NAME"
