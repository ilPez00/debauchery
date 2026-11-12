#!/bin/bash
# 06 — Physis omarchy adapter: build, test, deploy.
#
# The adapter's install.sh now honours `--dry-run` (fixed 2026-11-12);
# OMARCHY_DEBIAN_DRY_RUN=1 still works.
#
# Usage: ./06-physis-adapter.sh [test|dry-run|install|uninstall]
set -euo pipefail

ADAPTER="$HOME/dev/physis-next/adapters/omarchy"
ACTION=${1:-test}

[ -d "$ADAPTER" ] || { echo "adapter not found at $ADAPTER" >&2; exit 1; }

case "$ACTION" in
  test)
    cd "$HOME/dev/physis-next"
    cargo test --manifest-path adapters/omarchy/Cargo.toml
    ./adapters/omarchy/demo.sh --mock
    ;;
  dry-run)
    cd "$HOME/dev/physis-next"
    bash adapters/omarchy/install.sh --dry-run
    ;;
  install)
    cd "$HOME/dev/physis-next"
    bash adapters/omarchy/install.sh --dry-run   # inspect first
    ./adapters/omarchy/install.sh
    systemctl --user daemon-reload
    # only does anything in a Hyprland session; under niri the unit stays inactive
    systemctl --user try-restart physis-omarchy || true
    ;;
  uninstall)
    cd "$ADAPTER" && ./uninstall.sh
    ;;
  *)
    echo "usage: $0 [test|dry-run|install|uninstall]" >&2
    exit 1
    ;;
esac
