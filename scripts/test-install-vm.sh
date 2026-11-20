#!/bin/bash
# test-install-vm.sh — VM gate for the full installer (written for v0.3.0; the
# live run is PENDING until qemu is installed: sudo apt install qemu-system-x86).
#
# Boots the Debian 13 netinst ISO in qemu/KVM with the rendered preseed, which
# runs bootstrap.sh in late_command, then gates over ssh:
#   install.sh doctor --json  (non-session fails must be 0)
#   install.sh selftest       (automatic checks)
#   hyprctl binds -j          (>= 20 after autologin)
#
# The installer kernel/initrd are EXTRACTED FROM THE ISO (never the host's).
# A throwaway ed25519 keypair is generated per run and injected via preseed.
#
# Usage: ./scripts/test-install-vm.sh [--keep] [--user NAME] [--password-hash HASH]
#                                     [--gate-only] [--dry-run]
#   --keep             leave the VM dir (disk, console logs, key) for debugging
#   --user NAME        VM username (default: debauchery)
#   --password-hash    SHA-512 crypt hash from `mkpasswd -m sha-512` (required)
#   --gate-only        skip the install; boot an existing installed disk and gate
#   --dry-run          print the plan, change nothing
# Env: VM_SSH_TIMEOUT_MIN (install phase, default 120),
#      VM_BOOT_TIMEOUT_MIN (ssh wait, default 30), VM_REUSE_DISK=1
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=0 KEEP=0 GATE_ONLY=0 VM_USER="debauchery" PASSWORD_HASH=""

# Pinned Debian 13.7.0 netinst ISO (sha256 verified on the 2026-11-20 fetch).
# If the URL moves to a new point release, re-verify and re-pin.
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
ISO_SHA256="a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355"

usage() { sed -n '2,21p' "$0"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --keep)            KEEP=1; shift ;;
    --gate-only)       GATE_ONLY=1; shift ;;
    --user)            VM_USER=${2:-}; shift 2 ;;
    --user=*)          VM_USER=${1#*=}; shift ;;
    --password-hash)   PASSWORD_HASH=${2:-}; shift 2 ;;
    --password-hash=*) PASSWORD_HASH=${1#*=}; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'FAIL: %s\n' "$*" >&2; exit 2; }

VM_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/debauchery/vm"
ISO_FILE="$VM_DIR/debian-13-netinst.iso"
DISK="$VM_DIR/disk.qcow2"
KERNEL="$VM_DIR/vmlinuz"
INITRD="$VM_DIR/initrd.gz"
PRESEED="$VM_DIR/preseed.cfg"
VM_KEY="$VM_DIR/id_vm"
CONSOLE="$VM_DIR/console.log"
HTTP_PORT=8765
SSH_PORT=2222
QEMU_PID="" HTTP_PID=""

cleanup() {
  [ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
  [ -n "$HTTP_PID" ] && kill "$HTTP_PID" 2>/dev/null || true
}
trap cleanup EXIT

if [ "$DRY_RUN" = 1 ]; then
  log "== test-install-vm.sh --dry-run =="
  log "VM user: $VM_USER   dir: $VM_DIR   gate-only: $GATE_ONLY"
  log "ISO: $ISO_URL (sha256 pinned)"
  log "kernel/initrd extracted from ISO (install.amd/), NOT the host's"
  log "preseed rendered with __USER__/__PASSWORD_HASH__/__SSH_PUBKEY__"
  log "qemu: kvm, 3G, 2 cpus, 16G qcow2, virtio disk+net, virtio-vga-gl, egl-headless"
  log "      hostfwd tcp::$SSH_PORT-:22, serial -> $CONSOLE"
  log "append: console=ttyS0 auto=true url=http://10.0.2.2:$HTTP_PORT/preseed.cfg priority=critical"
  log "phase 1: installer (-kernel d-i + preseed), waits for POWEROFF"
  log "phase 2: boot installed disk (no -kernel), ssh gate"
  log "gate: ssh -i $VM_KEY; doctor non-session fails=0; selftest; binds >= 20"
  exit 0
fi

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu missing — install with: sudo apt install qemu-system-x86"
[ -e /dev/kvm ] || die "/dev/kvm missing"
mkdir -p "$VM_DIR"

if [ "$GATE_ONLY" = 0 ]; then
[ -n "$PASSWORD_HASH" ] || die "--password-hash required (generate with: mkpasswd -m sha-512)"

# ISO
if [ ! -f "$ISO_FILE" ]; then
  log "Downloading ISO..."
  curl -fL --retry 3 -o "$ISO_FILE" "$ISO_URL" || die "ISO download failed"
fi
if [ -n "$ISO_SHA256" ]; then
  echo "$ISO_SHA256  $ISO_FILE" | sha256sum -c - || die "ISO sha256 mismatch"
else
  warn "ISO sha256 unpinned — record $(sha256sum "$ISO_FILE" | awk '{print $1}') in this header after verification"
fi

# Extract the installer kernel/initrd from the ISO (user-space tools only)
if [ ! -f "$KERNEL" ] || [ ! -f "$INITRD" ]; then
  log "Extracting installer kernel/initrd from ISO..."
  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$ISO_FILE" -C "$VM_DIR" install.amd/vmlinuz install.amd/initrd.gz || die "bsdtar extract failed"
    mv -f "$VM_DIR/install.amd/vmlinuz" "$KERNEL"
    mv -f "$VM_DIR/install.amd/initrd.gz" "$INITRD"
  elif command -v isoinfo >/dev/null 2>&1; then
    isoinfo -i "$ISO_FILE" -x /install.amd/vmlinuz > "$KERNEL" || die "isoinfo vmlinuz failed"
    isoinfo -i "$ISO_FILE" -x /install.amd/initrd.gz > "$INITRD" || die "isoinfo initrd failed"
  elif command -v 7z >/dev/null 2>&1; then
    7z x -y -o"$VM_DIR" "$ISO_FILE" install.amd/vmlinuz install.amd/initrd.gz >/dev/null || die "7z extract failed"
    mv -f "$VM_DIR/install.amd/vmlinuz" "$KERNEL"
    mv -f "$VM_DIR/install.amd/initrd.gz" "$INITRD"
  else
    die "need bsdtar (libarchive-tools), isoinfo (genisoimage) or 7z (p7zip-full) to extract the ISO kernel"
  fi
fi

# Throwaway gate keypair + rendered preseed
[ -f "$VM_KEY" ] || ssh-keygen -t ed25519 -f "$VM_KEY" -N "" -C debauchery-vm-gate -q
PUBKEY=$(cat "$VM_KEY.pub")
sed -e "s/__USER__/$VM_USER/g" \
    -e "s|__PASSWORD_HASH__|$PASSWORD_HASH|g" \
    -e "s|__SSH_PUBKEY__|$PUBKEY|g" \
  "$REPO/configs/preseed.cfg" > "$PRESEED"

# Disk (an interrupted install leaves an unbootable disk — recreate unless asked).
# 16G: d-i uses ~3G, bootstrap's default gate wants 10G free, desktop ~4G more.
if [ -f "$DISK" ] && [ "${VM_REUSE_DISK:-0}" != 1 ]; then
  log "Removing stale disk from a previous run"
  rm -f "$DISK"
fi
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 16G >/dev/null

# Preseed http server (slirp guest reaches the host loopback via 10.0.2.2)
(cd "$VM_DIR" && exec python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
HTTP_PID=$!
sleep 1

log "Phase 1: installer boot (console -> $CONSOLE)..."
qemu-system-x86_64 \
  -enable-kvm -m 3072 -cpu host -smp 2 \
  -drive file="$DISK",format=qcow2,if=virtio \
  -cdrom "$ISO_FILE" \
  -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl -display egl-headless \
  -serial file:"$CONSOLE" \
  -kernel "$KERNEL" -initrd "$INITRD" \
  -append "console=ttyS0 auto=true url=http://10.0.2.2:$HTTP_PORT/preseed.cfg priority=critical" &
QEMU_PID=$!

# The preseed powers the VM off after late_command. Waiting for ssh here would
# loop the installer forever: -kernel reloads d-i on every reboot (observed:
# 13 install cycles in 120 min). Wait for the poweroff, then boot the disk.
TIMEOUT_MIN=${VM_SSH_TIMEOUT_MIN:-120}
log "Waiting for installer to finish and power off (timeout ${TIMEOUT_MIN} min)..."
for i in $(seq 1 $((TIMEOUT_MIN * 4))); do
  kill -0 "$QEMU_PID" 2>/dev/null || break
  if [ $((i % 20)) = 0 ]; then
    log "  ...$((i / 4)) min elapsed; console: $(tail -c 400 "$CONSOLE" | tr -d '\r' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tr -s ' \n' ' ' | tail -c 120)"
  fi
  sleep 15
done
if kill -0 "$QEMU_PID" 2>/dev/null; then
  tail -c 2000 "$CONSOLE" >&2
  die "installer did not power off within ${TIMEOUT_MIN} min (console tail above)"
fi
wait "$QEMU_PID" 2>/dev/null || true
QEMU_PID=""
kill "$HTTP_PID" 2>/dev/null || true
HTTP_PID=""
log "Installer powered off — phase 2: booting the installed system"
else
  [ -f "$DISK" ] || die "--gate-only: no installed disk at $DISK — run a full install first"
  [ -f "$VM_KEY" ] || die "--gate-only: no gate key at $VM_KEY"
  log "Gate-only: booting existing installed disk"
fi

BOOT_CONSOLE="$VM_DIR/console-boot.log"
qemu-system-x86_64 \
  -enable-kvm -m 3072 -cpu host -smp 2 \
  -drive file="$DISK",format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl -display egl-headless \
  -serial file:"$BOOT_CONSOLE" &
QEMU_PID=$!

SSH_OPTS=(-i "$VM_KEY" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT")
BOOT_TIMEOUT_MIN=${VM_BOOT_TIMEOUT_MIN:-30}
log "Waiting for SSH on 127.0.0.1:$SSH_PORT (timeout ${BOOT_TIMEOUT_MIN} min)..."
up=0
for i in $(seq 1 $((BOOT_TIMEOUT_MIN * 4))); do
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" true 2>/dev/null; then up=1; break; fi
  if [ $((i % 20)) = 0 ]; then
    log "  ...$((i / 4)) min; boot console: $(tail -c 300 "$BOOT_CONSOLE" | tr -d '\r' | tr -s ' \n' ' ' | tail -c 120)"
  fi
  sleep 15
done
[ "$up" = 1 ] || { tail -c 2000 "$BOOT_CONSOLE" >&2; die "SSH timeout after install (${BOOT_TIMEOUT_MIN} min)"; }
log "SSH up"

vm() { ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "$@"; }

# Gate 1: doctor — session-dependent checks (dms, binds-live) may fail before
# the first graphical login settles; everything else must be clean.
log "Gate: install.sh doctor --json"
vm "cd ~/debauchery && ./install.sh doctor --json" > "$VM_DIR/doctor.json" || true
python3 - "$VM_DIR/doctor.json" <<'PY' || die "doctor gate failed"
import json, sys
d = json.loads(open(sys.argv[1]).read(), strict=False)
session_checks = {"dms", "binds-live", "session"}
hard = [c for c in d["checks"] if c["status"] == "FAIL" and c["check"] not in session_checks]
soft = [c for c in d["checks"] if c["status"] == "FAIL" and c["check"] in session_checks]
for c in hard: print("  HARD FAIL:", c["check"], c["detail"])
for c in soft: print("  session-pending:", c["check"], c["detail"])
print(f"  doctor: fails={d['fails']} warns={d['warns']} hard_non_session={len(hard)}")
sys.exit(1 if hard else 0)
PY
log "doctor: PASS (no non-session failures)"

# Gate 2: selftest (automatic part)
log "Gate: install.sh selftest"
vm "cd ~/debauchery && ./install.sh selftest" || die "selftest failed"

# Gate 3: live binds after autologin (Hyprland on virtio-vga-gl)
log "Gate: hyprctl binds count"
BINDS=$(vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t $XDG_RUNTIME_DIR/hypr/ 2>/dev/null | head -1); hyprctl binds -j 2>/dev/null | grep -o "\"dispatcher\"" | wc -l' || echo 0)
if [ "${BINDS:-0}" -ge 20 ]; then
  log "hyprctl binds: $BINDS (>= 20) — PASS"
else
  warn "binds=$BINDS — autologin/Hyprland may need a console look (see $BOOT_CONSOLE)"
  die "live binds gate failed"
fi

log "=== ALL VM GATES PASSED ==="
if [ "$KEEP" = 0 ]; then
  kill "$QEMU_PID" 2>/dev/null || true
  rm -rf "$VM_DIR"
  log "VM dir cleaned (use --keep to retain)"
else
  log "VM kept at $VM_DIR (disk, console.log, key)"
fi
