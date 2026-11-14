#!/bin/bash
# install.sh — installer, updater, doctor for the Debian→Omarchy layer on air.
#
#   ./install.sh                     menu (TTY) / status (piped)
#   ./install.sh doctor [--json]     read-only health report      (agent-safe)
#   ./install.sh status              what is installed and what drifted
#   ./install.sh config              settings: keymap, look, plugins (TUI; prints when piped)
#   ./install.sh selftest            read-only smoke test + the manual key list
#   ./install.sh install [--profile core|feel|arch|apple|all]
#                        [--only id,id] [--yes] [--dry-run] [--no-sudo]
#   ./install.sh update              git pull --ff-only, re-apply, doctor
#   ./install.sh binds niri|omarchy  switch the keybind profile
#   ./install.sh set KEY=VALUE       write ~/.config/debauchery/config
#   ./install.sh uninstall [--all]   undo this layer (system bits are printed)
#
# Exit codes: 0 healthy / done, 1 warnings only, 2 failure or bad preflight.
# Logs: ~/.local/state/debauchery/install-<timestamp>.log
#
# The numbered scripts it calls are the same ones the repo documents; this file
# adds ordering, preflight, idempotence, a single undo and a read-only doctor.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DBVERSION=$(tr -d '[:space:]' < "$REPO/VERSION" 2>/dev/null || echo unknown)
MODULES=$REPO/modules.conf
CONFIG=${DEBAUCHERY_CONFIG:-$HOME/.config/debauchery/config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/debauchery
SELF=$REPO/install.sh

DRY=0 YES=0 NO_SUDO=0 JSON=0
PROFILE="" ONLY="" ACTION="" REST=()

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_pass=$'\033[32m'; c_warn=$'\033[33m'; c_fail=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
else
  c_pass=""; c_warn=""; c_fail=""; c_dim=""; c_off=""
fi

log()  { [ "${JSON:-0}" = 1 ] && return 0; printf '%s\n' "$*"; [ -n "${LOG_READY:-}" ] && printf '%s\n' "$*" >> "$LOG"; return 0; }
warn() { [ "${JSON:-0}" = 1 ] && return 0; printf '%s\n' "$*" >&2; [ -n "${LOG_READY:-}" ] && printf 'WARN %s\n' "$*" >> "$LOG"; return 0; }
die()  { printf '%s\n' "$*" >&2; exit 2; }
hr()   { log "${c_dim}────────────────────────────────────────────────────────────${c_off}"; }

# run: the only place mutations happen, so --dry-run has exactly one gate.
run() {
  if [ "$DRY" = 1 ]; then log "[dry-run] $*"; return 0; fi
  log "  \$ $*"
  "$@"
}

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"; }

load_config() {
  [ -r "$CONFIG" ] || return 0
  # shellcheck disable=SC1090
  set -a; . "$CONFIG"; set +a
}

cfg_get() { # key -> value
  load_config
  local name=$1
  eval "printf '%s\n' \"\${$name:-}\""
}

cfg_set() { # key value
  local key=$1 val=$2
  [ -d "${CONFIG%/*}" ] || mkdir -p "${CONFIG%/*}"
  [ -f "$CONFIG" ] || {
    { echo "# ~/.config/debauchery/config — written by install.sh set"
      echo "# Defaults and comments live in configs/debauchery/config.example"
    } > "$CONFIG"
  }
  if [ "$DRY" = 1 ]; then log "[dry-run] would set $key=$val in $CONFIG"; return 0; fi
  awk -v k="$key" -v v="$val" '
    BEGIN { done = 0 }
    index($0, k "=") == 1 { print k "=" v; done = 1; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
  log "config: $key=$val"
}

# --- module table -----------------------------------------------------------
# Emits one normalised row per module, in file order.
module_rows() {
  local line id script scope profiles check
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS='|' read -r id script scope profiles check <<<"$line"
    printf '%s|%s|%s|%s|%s\n' \
      "$(trim "$id")" "$(trim "$script")" "$(trim "$scope")" \
      "$(trim "$profiles")" "$(trim "$check")"
  done < "$MODULES"
}

row_for() { # id -> row
  module_rows | awk -F'|' -v id="$1" '$1 == id { print; exit }'
}

all_ids() { module_rows | cut -d'|' -f1; }

check_ok() { bash -c "$1" </dev/null >/dev/null 2>&1; }

selected_ids() {
  local id script scope profiles check want
  want=${PROFILE:-core}
  while IFS='|' read -r id script scope profiles check; do
    if [ -n "$ONLY" ]; then
      case ",$ONLY," in *",$id,"*) printf '%s\n' "$id" ;; esac
    else
      case ",$profiles," in *",$want,"*) printf '%s\n' "$id" ;; esac
    fi
  done < <(module_rows)
}

# --- sudo -------------------------------------------------------------------
SUDO_KEEPALIVE=""
ensure_sudo() {
  [ "$NO_SUDO" = 1 ] && return 1
  if sudo -n true 2>/dev/null; then return 0; fi
  if [ "$YES" = 1 ] || [ ! -t 0 ]; then
    warn "sudo needs a password and there is no TTY to ask for it."
    warn "Run 'sudo -v' first, or pass --no-sudo to skip the root modules."
    return 1
  fi
  sudo -v || return 1
  ( while kill -0 "$$" 2>/dev/null; do sleep 50; sudo -n true 2>/dev/null || exit 0; done ) &
  SUDO_KEEPALIVE=$!
  trap '[ -n "$SUDO_KEEPALIVE" ] && kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
  return 0
}

# --- preflight --------------------------------------------------------------
preflight() {
  local rc=0 free min
  . /etc/os-release 2>/dev/null || true
  log "preflight — $DBVERSION on $(uname -n) (${PRETTY_NAME:-unknown})"
  hr
  if [ "$(id -u)" -eq 0 ]; then warn "  FAIL  do not run this as root"; rc=1
  else log "  ok    unprivileged user $(id -un)"; fi

  if [ "${ID:-}" = debian ] && [ "${VERSION_ID:-}" = 13 ]; then
    log "  ok    Debian 13 (trixie)"
  else
    warn "  FAIL  expected Debian 13, found ${PRETTY_NAME:-unknown}"; rc=1
  fi

  min=$(cfg_get DEBAUCHERY_MIN_DISK_G); min=${min:-5}
  free=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
  if [ "${free:-0}" -ge "$min" ]; then log "  ok    disk: ${free}G free on /"
  else warn "  FAIL  disk: ${free}G free on / — need ${min}G (container/AUR modules will refuse)"; rc=1; fi

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) log "  ok    ~/.local/bin on PATH" ;;
    *) warn "  WARN  ~/.local/bin is not on PATH; the bridge and shims will not resolve" ;;
  esac

  if grep -rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    log "  ok    trixie-backports configured"
  else
    warn "  WARN  trixie-backports missing; Hyprland module cannot install"
  fi

  if [ -f /etc/pacman.conf ] && [ ! -f /etc/debian_version ]; then
    warn "  FAIL  this is an Arch container, not the Debian host"; rc=1
  fi
  return $rc
}

# --- modules ----------------------------------------------------------------
module_args() { # id -> extra args for its script
  case "$1" in
    physis) printf 'install' ;;
    fnrow)  printf '2' ;;
  esac
}

native_step() { # id
  case "$1" in
    zsh)   native_zsh ;;
    binds) native_binds ;;
    *) warn "no native implementation for module '$1'"; return 1 ;;
  esac
}

run_module() { # id script scope
  local id=$1 script=$2 scope=$3 args
  if [ "$script" = "-" ]; then
    if [ "$DRY" = 1 ]; then log "  [dry-run] native step: $id"; return 0; fi
    native_step "$id"
    return $?
  fi
  [ -f "$REPO/$script" ] || { warn "  FAIL  $id: missing $script"; return 1; }

  if [ "$DRY" = 1 ]; then
    log "  [dry-run] would run: $script $(module_args "$id")"
    if check_ok "$(row_for "$id" | cut -d'|' -f5)"; then log "            currently installed"
    else log "            currently absent"; fi
    return 0
  fi

  args=$(module_args "$id")
  if [ "$scope" = root ]; then
    if ! ensure_sudo; then warn "  SKIP  $id (needs root; --no-sudo)"; return 0; fi
    # shellcheck disable=SC2086
    run sudo bash "$REPO/$script" $args
  else
    # shellcheck disable=SC2086
    run bash "$REPO/$script" $args
  fi
}

native_zsh() {
  deploy_file "$REPO/configs/zsh/debauchery.zsh" "$HOME/.config/debauchery/aliases.zsh" 644
  wire_zshrc "$HOME/.zshrc" '[ -f ~/.config/debauchery/aliases.zsh ] && source ~/.config/debauchery/aliases.zsh'
}

# binds_verify — the live config chain must parse. Prints the reason on failure.
binds_verify() {
  local out
  command -v Hyprland >/dev/null 2>&1 || return 0
  out=$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf" 2>&1)
  if grep -q 'config ok' <<<"$out"; then return 0; fi
  grep -E 'Config error' <<<"$out" | head -3 | sed 's/^/    /' >&2
  return 1
}

# binds_apply — deploy a profile, and never leave a rejected one live.
binds_apply() { # src profile
  local src=$1 profile=$2 live=$HOME/.config/hypr/binds.conf prev="" n
  [ -f "$live" ] && { prev=$(mktemp); cp -a "$live" "$prev"; }

  deploy_file "$src" "$live" 644 || return 1
  [ "$DRY" = 1 ] && return 0

  if ! binds_verify; then
    warn "  FAIL  binds: '$profile' rejected by Hyprland — restoring the previous file"
    [ -n "$prev" ] && { mv -f "$prev" "$live"; prev=""; }
    return 1
  fi
  log "  binds: $profile profile verified (config ok)"
  [ -n "$prev" ] && rm -f "$prev"

  # A failed parse earlier leaves the running session with no binds; Hyprland
  # does not retry on its own, so force a reload and prove the result.
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
    sleep 0.3
    n=$(hyprctl binds -j 2>/dev/null | grep -o '"dispatcher"' | wc -l)
    if [ "${n:-0}" -lt 20 ]; then
      warn "  FAIL  binds: the running session has only ${n:-0} binds — run: hyprctl reload"
      return 1
    fi
    log "  binds: $n binds live in this session"
  fi
  return 0
}

native_binds() {
  local profile src
  profile=$(cfg_get DEBAUCHERY_BINDS); profile=${profile:-niri}
  case "$profile" in
    niri)    src=$REPO/configs/hypr/binds.conf ;;
    omarchy) src=$REPO/configs/binds/omarchy.conf ;;
    *) warn "unknown bind profile '$profile' (niri|omarchy)"; return 1 ;;
  esac
  binds_apply "$src" "$profile"
}

deploy_file() { # src dst mode
  local src=$1 dst=$2 mode=${3:-644}
  [ -f "$src" ] || { warn "  FAIL  missing source $src"; return 1; }
  if [ "$DRY" = 1 ]; then log "  [dry-run] would install $src -> $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then log "  = $dst"; return 0; fi
  if [ -e "$dst" ] && [ ! -f "$dst.pre-debauchery" ]; then
    cp -a "$dst" "$dst.pre-debauchery" && log "  backed up $dst"
  fi
  # Atomic: `install` truncates in place, and Hyprland reloads on inotify — a
  # half-written binds.conf parses with no binds and the running session keeps
  # the empty set. Renaming a complete file is seen as one event.
  install -m"$mode" "$src" "$dst.new" && mv -f "$dst.new" "$dst" && log "  + $dst"
}

wire_zshrc() { # file line
  local file=$1 line=$2
  if [ "$DRY" = 1 ]; then log "  [dry-run] would source: $line"; return 0; fi
  if grep -qF "$line" "$file" 2>/dev/null; then log "  = $file already sources it"; return 0; fi
  [ -f "$file" ] || { warn "  FAIL  $file not found"; return 1; }
  [ -f "$file.pre-debauchery" ] || cp -a "$file" "$file.pre-debauchery"
  {
    printf '\n# --- aliases: debauchery (managed by install.sh; file lives in ~/.config/debauchery) ---\n'
    printf '%s\n' "$line"
  } >> "$file"
  log "  + $file sources ~/.config/debauchery/aliases.zsh"
}

# --- commands ---------------------------------------------------------------
cmd_install() {
  load_config
  [ -n "$PROFILE" ] || PROFILE=${DEBAUCHERY_PROFILE:-core}
  mkdir -p "$STATE"
  LOG=$STATE/install-$(date +%Y%m%d-%H%M%S).log
  LOG_READY=1
  preflight || { warn "preflight failed — nothing was changed"; return 2; }

  local ids id rc=0
  ids=$(selected_ids)
  [ -n "$ids" ] || die "no modules selected for profile '$PROFILE'"
  hr
  log "installing profile '$PROFILE' $( [ -n "$ONLY" ] && printf '(only: %s)' "$ONLY") $( [ "$DRY" = 1 ] && printf '[dry-run]')"
  hr
  for id in $ids; do
    IFS='|' read -r _ script scope _ _ <<<"$(row_for "$id")"
    log ""
    log "▸ $id ($scope)"
    run_module "$id" "$script" "$scope" || { warn "  FAIL  $id"; rc=1; }
  done
  hr
  [ "$rc" = 0 ] && log "install finished — run './install.sh doctor' before trusting it"
  [ "$rc" != 0 ] && warn "install finished with failures — see $LOG"
  [ "$PROFILE" = menu ] || cfg_set DEBAUCHERY_PROFILE "$PROFILE" >/dev/null
  return $rc
}

cmd_update() {
  load_config
  mkdir -p "$STATE"
  LOG_READY=1; LOG=$STATE/install-$(date +%Y%m%d-%H%M%S).log
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    run git -C "$REPO" pull --ff-only || warn "git pull refused — resolve divergence, then re-run"
  else
    warn "not a git checkout; skipping pull"
  fi
  PROFILE=${DEBAUCHERY_PROFILE:-core}
  cmd_install
}

cmd_binds() {
  local profile=${1:-}
  case "$profile" in
    niri|omarchy) ;;
    *) die "usage: $0 binds niri|omarchy" ;;
  esac
  cfg_set DEBAUCHERY_BINDS "$profile"
  native_binds
}

cmd_status() {
  load_config
  local id script scope profiles check state drift=0
  log "debauchery $DBVERSION — $(uname -n)"
  log "config   : $CONFIG"
  log "profile  : $(cfg_get DEBAUCHERY_PROFILE | tr -d '\n' || echo core)   binds: $(cfg_get DEBAUCHERY_BINDS | tr -d '\n' || echo niri)"
  hr
  printf '%-9s %-6s %-24s %s\n' MODULE SCOPE STATE PROFILES
  while IFS='|' read -r id script scope profiles check; do
    if check_ok "$check"; then state="${c_pass}ok${c_off}"; else state="${c_dim}--${c_off}"; fi
    printf -v pad '%-9s %-6s ' "$id" "$scope"
    printf '%b%s %s\n' "$pad" "$state" "$profiles"
  done < <(module_rows)
  hr
  log "drift (repo vs deployed):"
  while IFS='|' read -r src dst; do
    if [ ! -e "$dst" ]; then
      printf '  %-58s %s\n' "${dst/#$HOME/~}" "absent"; drift=1
    elif cmp -s "$REPO/$src" "$dst"; then
      printf '  %-58s %s\n' "${dst/#$HOME/~}" "current"
    else
      printf '  %-58s %s\n' "${dst/#$HOME/~}" "DRIFTED"; drift=1
    fi
  done < <(deploy_pairs)
  local bprof bsrc
  bprof=$(cfg_get DEBAUCHERY_BINDS); bprof=${bprof:-niri}
  case "$bprof" in omarchy) bsrc=$REPO/configs/binds/omarchy.conf ;; *) bsrc=$REPO/configs/hypr/binds.conf ;; esac
  if cmp -s "$bsrc" "$HOME/.config/hypr/binds.conf" 2>/dev/null; then
    printf '  %-58s %s\n' "~/.config/hypr/binds.conf" "$bprof profile"
  else
    printf '  %-58s %s\n' "~/.config/hypr/binds.conf" "DIFFERS from $bprof profile"; drift=1
  fi
  return $drift
}

deploy_pairs() {
  cat <<EOF
configs/bin/omarchy-arch|$HOME/.local/bin/omarchy-arch
configs/bin/omarchy-pkg|$HOME/.local/bin/omarchy-pkg
configs/bin/omarchy-shim|$HOME/.local/bin/omarchy-shim
configs/arch-debian.map|$HOME/.config/omarchy-bridge/arch-debian.map
configs/zsh/ssh-aliases.zsh|$HOME/.config/fleet/ssh-aliases.zsh
configs/zsh/debauchery.zsh|$HOME/.config/debauchery/aliases.zsh
EOF
}

cmd_doctor() {
  local fails=0 warns=0 rows=() detail status
  load_config
  emit() { # status name detail
    local s=$1 n=$2 d=${3//\"/\'}
    if [ "$JSON" = 1 ]; then
      rows+=("$(printf '{"status":"%s","check":"%s","detail":"%s"}' "$s" "$n" "$d")")
      return 0
    fi
    case "$s" in
      PASS) printf '%sPASS%s %-22s %s\n' "$c_pass" "$c_off" "$n" "$d" ;;
      WARN) printf '%sWARN%s %-22s %s\n' "$c_warn" "$c_off" "$n" "$d" ;;
      FAIL) printf '%sFAIL%s %-22s %s\n' "$c_fail" "$c_off" "$n" "$d" ;;
    esac
  }
  judge() { # status-ok status-bad name detail
    if check_ok "$1"; then emit PASS "$3" "$4"; else
      if [ "$2" = WARN ]; then emit WARN "$3" "$4"; warns=$((warns + 1))
      else emit FAIL "$3" "$4"; fails=$((fails + 1)); fi
    fi
  }

  [ "$JSON" = 1 ] || { log "debauchery $DBVERSION — doctor on $(uname -n)"; hr; }

  . /etc/os-release 2>/dev/null || true
  judge '. /etc/os-release && [ "$VERSION_ID" = 13 ] && [ "$ID" = debian ]' FAIL os "${PRETTY_NAME:-unknown} (want Debian 13)"
  judge 'command -v sudo >/dev/null' FAIL sudo "$(command -v sudo || echo missing)"
  judge 'command -v zsh >/dev/null' FAIL zsh "$(command -v zsh || echo missing)"
  judge 'command -v podman >/dev/null' FAIL podman "$(podman --version 2>/dev/null || echo missing)"
  judge 'command -v distrobox >/dev/null' WARN distrobox "$(command -v distrobox || echo 'missing (arch profile)')"
  judge "test -d '$REPO/scripts'" FAIL repo "$REPO"

  log ""
  log "session"
  judge '[ "${XDG_CURRENT_DESKTOP:-}" = Hyprland ]' WARN session "${XDG_CURRENT_DESKTOP:-none} (want Hyprland)"
  judge 'systemctl --user is-active --quiet dms.service' FAIL dms "dms.service $(systemctl --user is-active dms.service 2>/dev/null || echo unknown)"
  judge '! systemctl --user is-enabled xdg-desktop-portal-hyprland.service 2>/dev/null | grep -q masked' FAIL portal "xdg-desktop-portal-hyprland masked?"
  judge '[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/physis-omarchy.sock" ]' WARN physis-socket "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/physis-omarchy.sock"
  # A config that parses is not a session with working keys: a parse error at
  # reload time leaves the running instance with almost no binds.
  local live_binds=0
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && live_binds=$(hyprctl binds -j 2>/dev/null | grep -o '"dispatcher"' | wc -l)
  judge "test ${live_binds:-0} -ge 20" FAIL binds-live "${live_binds} binds in the running session (a healthy profile has ~150)"

  log ""
  log "container"
  judge 'distrobox list 2>/dev/null | grep -q "| arch-omarchy "' WARN archbox "$(podman ps -a --format '{{.Names}} {{.Status}}' 2>/dev/null | grep arch-omarchy || echo absent)"
  judge 'test -x "$HOME/.local/bin/omarchy-arch"' WARN gateway "$HOME/.local/bin/omarchy-arch"
  judge 'test -x "$HOME/.local/bin/omarchy-menu"' WARN shims "omarchy-* verbs installed?"

  log ""
  log "disk"
  detail=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
  local min_disk
  min_disk=$(cfg_get DEBAUCHERY_MIN_DISK_G); min_disk=${min_disk:-5}
  judge "test ${detail:-0} -ge $min_disk" FAIL disk "${detail:-?}G free on / (need ${min_disk}G)"

  log ""
  log "drift"
  local src dst
  while IFS='|' read -r src dst; do
    if cmp -s "$REPO/$src" "$dst" 2>/dev/null; then
      emit PASS "file:$(basename "$dst")" "current"
    elif [ -e "$dst" ]; then
      emit FAIL "file:$(basename "$dst")" "differs from $src"
      fails=$((fails + 1))
    else
      emit WARN "file:$(basename "$dst")" "not deployed"
      warns=$((warns + 1))
    fi
  done < <(deploy_pairs)

  # binds are profile-aware: the deployed file must match the profile in config.
  local bprof bsrc
  bprof=$(cfg_get DEBAUCHERY_BINDS); bprof=${bprof:-niri}
  case "$bprof" in omarchy) bsrc=$REPO/configs/binds/omarchy.conf ;; *) bsrc=$REPO/configs/hypr/binds.conf ;; esac
  if cmp -s "$bsrc" "$HOME/.config/hypr/binds.conf" 2>/dev/null; then
    emit PASS "binds-profile" "$bprof profile installed"
  else
    emit FAIL "binds-profile" "deployed binds.conf does not match profile '$bprof'"
    fails=$((fails + 1))
  fi

  log ""
  log "modules"
  local id script scope profiles check
  while IFS='|' read -r id script scope profiles check; do
    if check_ok "$check"; then emit PASS "$id" "installed"
    else emit WARN "$id" "not installed"; warns=$((warns + 1)); fi
  done < <(module_rows)

  if [ "$JSON" = 1 ]; then
    printf '{"version":"%s","host":"%s","fails":%d,"warns":%d,"checks":[%s]}\n' \
      "$DBVERSION" "$(uname -n)" "$fails" "$warns" "$(IFS=,; echo "${rows[*]}")"
  else
    hr
    log "fails: $fails   warns: $warns"
    [ "$fails" = 0 ] && log "healthy enough to trust — no hard failures"
    [ "$fails" != 0 ] && warn "FAILURES above are broken, not merely uninstalled"
  fi
  [ "$fails" != 0 ] && return 2
  [ "$warns" != 0 ] && return 1
  return 0
}

cmd_uninstall() {
  local all=0
  [ "${1:-}" = --all ] && all=1
  log "uninstalling the user-scope layer (system packages are never touched)"
  for step in scripts/11-omarchy-shims.sh scripts/08-arch-bridge.sh scripts/09-ssh-aliases.sh; do
    [ -f "$REPO/$step" ] && run bash "$REPO/$step" --uninstall
  done
  if [ -f "$HOME/.config/hypr/binds.conf.pre-debauchery" ]; then
    run mv -f "$HOME/.config/hypr/binds.conf.pre-debauchery" "$HOME/.config/hypr/binds.conf"
  fi
  if grep -qF 'debauchery/aliases.zsh' "$HOME/.zshrc" 2>/dev/null; then
    run bash -c "grep -vF 'debauchery/aliases.zsh' '$HOME/.zshrc' | grep -vF 'aliases: debauchery (managed' > '$HOME/.zshrc.tmp' && mv -f '$HOME/.zshrc.tmp' '$HOME/.zshrc'"
  fi
  run rm -f "$HOME/.config/debauchery/aliases.zsh"
  hr
  log "still present by design: Hyprland packages, the arch-omarchy container, the Physis adapter."
  if [ "$all" = 1 ]; then
    log "their undo commands:"
    bash "$REPO/scripts/07-rollback.sh" all | sed 's/^/  /'
  else
    log "add --all to print the undo commands for those."
  fi
  return 0
}

cmd_selftest() {
  local fails=0
  step() { # label command...
    local label=$1; shift
    if "$@" >/dev/null 2>&1; then log "  ${c_pass}ok${c_off}    $label"
    else warn "  ${c_fail}FAIL${c_off}  $label"; fails=$((fails + 1)); fi
  }
  have() { bash -c "$1" >/dev/null 2>&1; }

  log "selftest — read-only. Nothing is toggled, no window is opened."
  hr
  log "shim layer"
  step "omarchy-shim backends" "$HOME/.local/bin/omarchy-shim" --check
  local v missing=""
  for v in $("$HOME/.local/bin/omarchy-shim" --list 2>/dev/null); do
    [ -L "$HOME/.local/bin/omarchy-$v" ] || missing="$missing $v"
  done
  if [ -z "$missing" ]; then
    log "  ${c_pass}ok${c_off}    $("$HOME/.local/bin/omarchy-shim" --list 2>/dev/null | wc -l) verbs linked"
  else
    warn "  ${c_fail}FAIL${c_off}  verbs not linked:$missing"; fails=$((fails + 1)); fi

  log ""
  log "shell"
  step "dms ipc answers" dms ipc call plugins list
  step "dms plugins registry (network)" bash -c 'dms plugins list 2>/dev/null | grep -q "Installed Plugins"'
  local n_binds=0 n_pl=0 n_off=0
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && n_binds=$(hyprctl binds -j 2>/dev/null | grep -o '"dispatcher"' | wc -l)
  n_pl=$(dms ipc call plugins list 2>/dev/null | grep -c '\[loaded\]')
  n_off=$(dms ipc call plugins list 2>/dev/null | grep -c '\[disabled\]')
  if [ "${n_binds:-0}" -ge 20 ]; then log "  ${c_pass}ok${c_off}    $n_binds binds live in this session"; else
    warn "  ${c_fail}FAIL${c_off}  ${n_binds:-0} binds — run: hyprctl reload"; fails=$((fails + 1)); fi
  log "  ${c_dim}--${c_off}    plugins: $n_pl loaded, $n_off disabled"

  # Every verb the omarchy keymap calls must exist, or the key is silently dead.
  local dead=""
  for v in $(grep -ohE 'omarchy-[a-z-]+' "$REPO/configs/binds/omarchy.conf" 2>/dev/null | sort -u); do
    command -v "$v" >/dev/null 2>&1 || dead="$dead $v"
  done
  if [ -z "$dead" ]; then log "  ${c_pass}ok${c_off}    every key in the omarchy keymap has a verb"; else
    warn "  ${c_fail}FAIL${c_off}  dead keys (no such command):$dead"; fails=$((fails + 1)); fi
  step "physis adapter socket" test -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/physis-omarchy.sock"

  hr
  log "what only you can see (each one is one keypress, all reversible)"
  cat <<'EOF'
  menus        SUPER+Space      dankMenu opens, Escape closes
               SUPER+X          power menu
               SUPER+Y          keybind cheatsheet
               SUPER+V          clipboard history
  capture      Print            region screenshot; file lands in ~/Pictures
               SUPER+CTRL+Print OCR a region to the clipboard   (needs tesseract)
               ALT+Print        start/stop a region recording    (needs wf-recorder)
  hardware     F1 / F2          display brightness down / up
               F5 / F6          keyboard backlight down / up
               F10              mute;  F11 / F12 volume
  look         omarchy-theme-toggle          dark <-> light
               omarchy-night-toggle          blue-light filter
  layout       omarchy-layout-toggle         dwindle <-> master
               omarchy-toggle-touchpad       trackpad off/on
  plugins      dms plugins browse            the store, in a terminal
               dms ipc call plugins list      id [loaded|disabled]
               dms ipc call plugins disable cavaVisualizer   (use enable/disable:
                                              `toggle` returns PLUGIN_TOGGLE_FAILED)
               dms plugins install batteryPlus   then RESTART dms.service:
                                              a new plugin is invisible until
                                              the shell restarts, and arrives
                                              disabled (plugins enable <id>)
               dms plugins lock               pins every plugin to a commit
               dms plugins restore            re-installs those exact commits

  The keys above are the omarchy profile. On the niri profile the verbs still
  work as commands; only SUPER+Space / SUPER+X / SUPER+V / SUPER+Y are bound.
  Switch with: ./install.sh binds omarchy     (back: ./install.sh binds niri)
EOF
  hr
  [ "$fails" = 0 ] && log "selftest: automatic checks pass — the rest is a keypress away"
  [ "$fails" != 0 ] && warn "selftest: $fails automatic check(s) failed"
  [ "$fails" = 0 ] || return 2
  return 0
}

cmd_config() {
  load_config
  local binds=${DEBAUCHERY_BINDS:-niri}

  # Marks are for the human reading this, not for a machine: every line is the
  # command that changes the thing.
  config_show() {
    local mode night layout pl
    mode=$(dms ipc call theme getMode 2>/dev/null || echo "?")
    night=$(dms ipc call night status 2>/dev/null | head -1 | sed 's/^[^:]*: *//' || echo "?")
    layout=$(hyprctl getoption general:layout 2>/dev/null | awk '/^str:/{print $2}')
    pl=$(dms ipc call plugin-scan list 2>/dev/null | tail -n +2 \
      | awk -F'\t' '$2=="loaded"{l++} END{printf "%d loaded", l+0}')
    printf '  %-12s %-14s %s\n' \
      keybinds     "$binds"        "./install.sh binds niri|omarchy" \
      appearance   "$mode"         "dms ipc call theme dark|light|toggle" \
      "night"      "${night:-?}"   "dms ipc call night enable|disable|toggle" \
      layout       "${layout:-?}"  "omarchy-layout-toggle" \
      plugins      "$pl"           "omarchy-plugin-list" \
      config       ""              "$CONFIG"
  }

  if ! command -v whiptail >/dev/null 2>&1 || [ ! -t 0 ]; then
    log "settings (no TTY: showing state and the command for each)"
    config_show
    return 0
  fi

  local choice
  while true; do
    choice=$(whiptail --title "debauchery $DBVERSION — settings" --menu \
      "Pick a section. Nothing security-relevant lives here." 22 78 12 \
      "1" "Keybind profile  ($binds)" \
      "2" "Appearance       (dark / light)" \
      "3" "Night filter     (blue light)" \
      "4" "Window layout    (dwindle / master)" \
      "5" "Plugins          (on / off)" \
      "6" "Touchpad         (on / off)" \
      "7" "Edit the config file" \
      "8" "Show every setting as a command" \
      "q" "Done" 3>&1 1>&2 2>&3) || return 0
    case "$choice" in
      1) local p
         p=$(whiptail --title "keybinds" --menu "Which keymap?" 15 60 4 \
           niri "your own keys (153 binds)" omarchy "Omarchy's key list (139 binds)" \
           3>&1 1>&2 2>&3) || continue
         cmd_binds "$p" && binds=$p ;;
      2) local m
         m=$(whiptail --title "appearance" --menu "Theme mode" 14 50 3 \
           dark "" light "" toggle "" 3>&1 1>&2 2>&3) || continue
         dms ipc call theme "$m" && log "theme: $m" ;;
      3) local n
         n=$(whiptail --title "night filter" --menu "Blue light filter" 14 50 3 \
           toggle "" enable "" disable "" 3>&1 1>&2 2>&3) || continue
         dms ipc call night "$n" && log "night: $n" ;;
      4) "$HOME/.local/bin/omarchy-layout-toggle" || cmd_install --only hyprland ;;
      5) config_plugins ;;
      6) local t
         t=$(whiptail --title "touchpad" --menu "Trackpad" 14 50 3 \
           toggle "" on "" off "" 3>&1 1>&2 2>&3) || continue
         "$HOME/.local/bin/omarchy-toggle-touchpad" "$t" ;;
      7) "${EDITOR:-nano}" "$CONFIG" ;;
      8) config_show ;;
      q|"") return 0 ;;
    esac
  done
}

# Plugin on/off as a checklist. `dms ipc call plugins enable|disable` acts live,
# no shell restart; a plugin that was just *installed* still needs one.
config_plugins() {
  local rows=() items=() picked on
  mapfile -t rows < <(dms ipc call plugin-scan list 2>/dev/null | tail -n +2)
  [ ${#rows[@]} -gt 0 ] || { warn "no plugins answered (is dms running?)"; return 1; }
  local id state kind name
  for r in "${rows[@]}"; do
    IFS=$'\t' read -r id state kind name <<<"$r"
    on=OFF; [ "$state" = loaded ] && on=ON
    items+=("$id" "$kind · ${name:-$id}" "$on")
  done
  picked=$(whiptail --title "plugins" --checklist \
    "Space toggles, Enter applies. Live change, no restart." 22 78 14 \
    "${items[@]}" 3>&1 1>&2 2>&3) || return 0
  picked=" $(tr -d '"' <<<"$picked") "
  for r in "${rows[@]}"; do
    IFS=$'\t' read -r id state kind name <<<"$r"
    case "$picked" in
      *" $id "*) verb=enable ;;
      *)         verb=disable ;;
    esac
    dms ipc call plugins "$verb" "$id" >/dev/null 2>&1 || warn "plugin $id: $verb failed"
  done
  log "plugins: $(dms ipc call plugin-scan list 2>/dev/null | tail -n +2 | awk -F'\t' '$2=="loaded"{l++} END{print l+0}') loaded"
}

cmd_menu() {
  command -v whiptail >/dev/null 2>&1 || { cmd_status; return 0; }
  load_config
  local items=() id script scope profiles check state
  while IFS='|' read -r id script scope profiles check; do
    if check_ok "$check"; then state="installed"; else state="absent"; fi
    items+=("$id" "$profiles · $state" "OFF")
  done < <(module_rows)
  local picked
  picked=$(whiptail --title "debauchery $DBVERSION" --checklist \
    "Select the modules to apply. Space toggles, Enter applies." 20 78 13 \
    "${items[@]}" 3>&1 1>&2 2>&3) || return 0
  picked=$(tr -d '"' <<<"$picked" | tr ' ' ',')
  [ -n "$picked" ] || { log "nothing selected"; return 0; }
  ONLY=$picked
  PROFILE=menu
  cmd_install
}

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$SELF"
  printf '\n  modules: %s\n' "$(all_ids | tr '\n' ' ')"
}

# --- main -------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)   PROFILE=${2:-}; shift 2 ;;
    --profile=*) PROFILE=${1#*=}; shift ;;
    --only)      ONLY=${2:-}; shift 2 ;;
    --only=*)    ONLY=${1#*=}; shift ;;
    --yes|-y)    YES=1; shift ;;
    --dry-run|-n) DRY=1; shift ;;
    --no-sudo)   NO_SUDO=1; shift ;;
    --json)      JSON=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "unknown flag: $1" ;;
    *)           if [ -z "$ACTION" ]; then ACTION=$1; else REST+=("$1"); fi; shift ;;
  esac
done

case "${ACTION:-}" in
  "")        if [ -t 0 ] && [ -t 1 ]; then cmd_menu; else cmd_status; fi ;;
  install)   cmd_install ;;
  update)    cmd_update ;;
  doctor)    cmd_doctor ;;
  selftest)  cmd_selftest ;;
  config)    cmd_config ;;
  status)    cmd_status ;;
  binds)     cmd_binds "${REST[0]:-}" ;;
  uninstall) cmd_uninstall "${REST[0]:-}" ;;
  set)
    case "${REST[0]:-}" in
      *=*) cfg_set "${REST[0]%%=*}" "${REST[0]#*=}" ;;
      *) die "usage: $0 set KEY=VALUE" ;;
    esac
    ;;
  get)
    [ -n "${REST[0]:-}" ] || die "usage: $0 get KEY"
    load_config; cfg_get "${REST[0]}"
    ;;
  version)   echo "$DBVERSION" ;;
  *)         usage; exit 2 ;;
esac
