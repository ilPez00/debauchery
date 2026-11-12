# Plan — Physis omarchy adapter (air)

> The Physis semantic layer over a Hyprland desktop. Source:
> `~/dev/physis-next/adapters/omarchy` (crate `physis-omarchy-adapter`, v1.8.8).
> Companion to `PLAN.md` and `MIGRATION-niri-to-hyprland.md`.

## 1. What it is

A **separate Rust crate** (not a member of the physis-next engine workspace) that
observes a Hyprland desktop into the Physis world and exposes typed operations
over a Unix socket. The engine only gains a new observation source
(`"hyprland"`); no migrations.

```
Hyprland IPC (socket2) ──┐
hyprctl -j              ──┤
/proc/<pid>/{exe,cwd}   ──┼──▶ physis-omarchy (adapter) ──▶ Physis world
.git walk               ──┘        │
                                  └─ UNIX socket $XDG_RUNTIME_DIR/physis-omarchy.sock
```

## 2. Objects and operations

- Objects: `workspace → window ← process → file`, `app:<class> → dir:<repo>`.
- Shortcuts: `SUPER+SHIFT+P` inspect, `SUPER+SHIFT+H` HUD, `SUPER+SHIFT+O` operations.
- Operations: `focus_window`, `switch_workspace`, `open_file`, `open_folder`,
  `open_terminal`, `inspect_repository`, `pin_to_notebook`, `query_relations`,
  `close_window` (destructive — requires explicit authorization).
- IPC methods: `ping`, `state`, `inspect`, `graph.neighbors`, `ops.list`,
  `ops.preview`, `ops.run`, `notebook.pin`, `notebook.list`.
- Hard limits: 64 KiB messages, `SO_PEERCRED` peer UID check, closed operation
  enum (no arbitrary shell execution).

## 3. Prerequisites (verified on air)

| Requirement | State |
|---|---|
| Hyprland + `hyprctl` | installed (0.55.2) |
| `~/.config/hypr/extra.conf` sourced by `hyprland.conf` | yes |
| `cargo` / `rustc` | installed (1.96.1) |
| Waybar / Fuzzel | **not installed** (optional; the adapter skips their integration) |
| `~/.local/bin/physis` (engine) | present |
| A running Hyprland session | **not yet logged in** |

**Deployed 2026-11-12** (Phase 5) while still in the niri session: binaries in
`~/.local/bin`, `~/.config/hypr/physis-omarchy.conf` + its `source` line in
`extra.conf`, the systemd user unit and the desktop entry. Only the **live
graphical smoke test** is outstanding — it needs a Hyprland seat.

Under niri the unit correctly stays `inactive (dead)`; the daemon exits with
`Hyprland session not found` instead of hanging or looping.

### air shortcut deviation

The integration file binds `SUPER+SHIFT P` (inspect), `SUPER+SHIFT H` (HUD) and
`SUPER+SHIFT O` (fuzzel ops). On air `binds.conf` already owns `SUPER SHIFT H`
(`movewindow, l`) and `extra.conf` is sourced **last**, so the adapter would
have silently stolen that movement bind. The HUD therefore moved to
**`SUPER+SHIFT G`** in `adapters/omarchy/hypr/physis-omarchy.conf`; `P` and `O`
were free and are unchanged. Revert the edit if air ever matches stock
Omarchy-Debian.

## 4. Installer bug (confirmed, **fixed 2026-11-12**)

The adapter `README.md` documents `./install.sh --dry-run`, but the script only
implements the environment variable:

```bash
DRY_RUN=${OMARCHY_DEBIAN_DRY_RUN:-0}     # install.sh:31
```

So `./install.sh --dry-run` **deploys instead of dry-running**. Correct usage:

```bash
cd ~/dev/physis-next
OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh
```

Recommended fix (one line, before the env default):

```bash
case "${1:-}" in --dry-run) DRY_RUN=1;; esac
```

**Applied 2026-11-12** to `install.sh` right after the `DRY_RUN` env default.
Verified: `./install.sh --dry-run` prints the plan and changes nothing
(`~/.config/hypr/extra.conf` md5 identical before/after, no binaries, no unit).

## 5. Build and test

```bash
cd ~/dev/physis-next
cargo test --manifest-path adapters/omarchy/Cargo.toml
./adapters/omarchy/demo.sh --mock
```

Expected: engine fold 56, adapter unit 33, fixtures 6, session/IPC 7, installer
dry-run/idempotence/uninstall pass, daemon-without-compositor pass. The
**graphical-session smoke test is UNVERIFIED** (needs a real Hyprland seat).

**Run 2026-11-12:** `cargo test --manifest-path adapters/omarchy/Cargo.toml` →
fixtures 6/6, session 7/7, remaining suites 0 tests, exit 0. `demo.sh --mock` →
all 12 steps PASS. Duplicate-bind check: `Hyprland --verify-config` → `config ok`.

## 6. Deploy

```bash
cd ~/dev/physis-next
OMARCHY_DEBIAN_DRY_RUN=1 bash adapters/omarchy/install.sh   # inspect the plan first
./adapters/omarchy/install.sh
systemctl --user daemon-reload
systemctl --user restart physis-omarchy
```

What it installs:

- `~/.local/bin/physis-omarchy`, `~/.local/bin/physis-omarchyd`
- `~/.config/hypr/physis-omarchy.conf` (sourced from `extra.conf`)
- Waybar `custom/physis` module (skipped if Waybar is absent)
- `~/.local/share/applications/physis-omarchy.desktop` + icon
- `~/.config/systemd/user/physis-omarchy.service`

It backs up modified user files to `<file>.pre-omarchy` and is idempotent.

## 7. Verify

```bash
# daemon running?
systemctl --user status physis-omarchy --no-pager
# socket present?
ls -l "$XDG_RUNTIME_DIR/physis-omarchy.sock"
# in the Hyprland session:
#   SUPER+SHIFT+P  → terminal inspector for the active window
#   SUPER+SHIFT+G  → Physis HUD   (air: H is taken by movewindow,l)
#   SUPER+SHIFT+O  → operation discovery
```

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Shortcuts do nothing | `hyprland.conf` does not source `extra.conf` | ensure `source = ~/.config/hypr/extra.conf` is present |
| `missing-pam` on lock | lock plugin needs a PAM file | not adapter-related; see PLAN.md kit step 72 |
| daemon exits cleanly, no socket | no compositor running | start Hyprland first |
| `cargo build` fails | toolchain too old / missing | `apt install -y cargo rustc` (done) |
| `--dry-run` deployed files | installer bug | use `OMARCHY_DEBIAN_DRY_RUN=1`; fix the flag |

## 9. Mismatches to resolve

1. **Shell target.** The adapter targets **Hyprland + Waybar + Fuzzel** (the
   CommunityPokeOrg/omarchy-debian shell). air uses **DMS**. The observer and
   typed operations are shell-independent, but the Waybar module and Fuzzel
   integration are dead weight on DMS. A DMS-aware surface would use the
   `dms ipc call hypr ...` targets instead.
2. **Compositor.** The adapter cannot observe niri; it requires Hyprland.
3. **Distrobox is not modelled.** The adapter has no container/package
   observation. Planned extension: treat `distrobox list` / `podman` as an
   execution-environment source, and link packages/executables/processes to the
   container that owns them (so a command can be dispatched as
   `distrobox enter arch-omarchy -- <tool>` vs `/usr/bin/<tool>`).

## 10. Rollback

```bash
cd ~/dev/physis-next/adapters/omarchy
./uninstall.sh
```

Restores the backed-up files and removes the deployed ones.
