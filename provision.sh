#!/usr/bin/env bash
#
# provision.sh — Post-install provisioning for Kali Linux on a Lenovo ThinkPad T490s
#
# Run this AFTER a fresh Kali install (see README.md for the install walkthrough).
# It is idempotent: safe to re-run, and you can run individual modules.
#
# Usage:
#   sudo ./provision.sh                 # run every module in order
#   sudo ./provision.sh all             # same as above
#   sudo ./provision.sh 10 30           # run only modules 10-dev and 30-osint
#   ./provision.sh list                 # list available modules (no root needed)
#   ./provision.sh doctor               # run only the preflight checks
#   ./provision.sh --dry-run            # print the install plan, change nothing
#   RUN_USER=anon sudo ./provision.sh   # override the target (non-root) user
#
# Every run is logged to /var/log/kali-t490s-<timestamp>.log (override: LOGFILE=...).
#
set -euo pipefail

# --- resolve paths ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
export SCRIPT_DIR LIB_DIR
export DEBIAN_FRONTEND=noninteractive

# --- parse flags (separate from module selectors) ---------------------------
DRY_RUN=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done
export DRY_RUN
set -- "${ARGS[@]:-all}"
CMD="$1"

# --- module registry (ordered) ---------------------------------------------
MODULES=(
  "00-base"
  "10-dev"
  "12-dev-extras"
  "15-vmlab"
  "20-browsers-comms"
  "25-anonymity"
  "30-osint"
  "35-offensive"
  "36-webapp"
  "37-wireless"
  "38-pivoting"
  "40-productivity"
  "45-engagements"
  "50-hardening"
  "52-hwtoken"
  "54-keys"
  "60-thinkpad"
  "70-resilience"
  "80-extras"
  "82-qol"
  "90-dotfiles"
  "95-firstboot"
)

# --- 'list' needs no root and no helpers ------------------------------------
if [[ "$CMD" == "list" ]]; then
  echo "Available modules:"
  printf '  %s\n' "${MODULES[@]}"
  exit 0
fi

# --- select which modules this invocation targets ---------------------------
selected=()
if [[ "$CMD" == "all" || "$CMD" == "doctor" ]]; then
  selected=("${MODULES[@]}")
else
  for arg in "$@"; do
    for m in "${MODULES[@]}"; do
      [[ "$m" == "${arg}"* ]] && selected+=("$m")
    done
  done
  [[ ${#selected[@]} -eq 0 ]] && { echo "no module matched: $*" >&2; exit 1; }
fi

# ============================================================================
# DRY RUN — static plan, executes nothing (no root required)
# ============================================================================
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "== DRY RUN — install plan (nothing is changed) =="
  for m in "${selected[@]}"; do
    file="$LIB_DIR/${m}.sh"; [[ -f "$file" ]] || continue
    echo; echo "### $m"
    # join backslash-continued lines so multi-line apt_install lists are whole
    joined="$(sed -e ':a' -e '/\\$/{N;s/\\\n/ /;ta}' "$file")"
    # apt packages — one "apt:" line per apt_install call; strip || and # tails
    printf '%s\n' "$joined" \
      | grep -E '(^|[[:space:]])apt_install[[:space:]]' \
      | grep -vE 'apt_install_file' \
      | sed -E 's/.*apt_install[[:space:]]+//; s/[[:space:]]*\|\|.*//; s/#.*//' \
      | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g' \
      | sed '/^$/d; s/^/  apt: /' || true
    # third-party repos + .debs + language installers (|| true: no match is fine)
    printf '%s\n' "$joined" | grep -oE 'add_apt_repo "[^"]+"' | sed 's/add_apt_repo /  repo: /' || true
    printf '%s\n' "$joined" | grep -oE 'install_deb "[^"]+"'  | sed 's/install_deb /  deb: /'  || true
    printf '%s\n' "$joined" | grep -oE '(pipx install|go install|cargo install|npm i(nstall)? -g|--install-extension) [^"'"'"']+' \
      | sed 's/^/  tool: /' || true
  done
  echo; echo "== end of plan =="
  exit 0
fi

# ============================================================================
# REAL RUN
# ============================================================================
if [[ "${EUID}" -ne 0 ]]; then
  echo "This must run as root. Use: sudo $0 $*   (or './provision.sh doctor|list|--dry-run' without root)" >&2
  exit 1
fi

# target (non-root) user
RUN_USER="${RUN_USER:-${SUDO_USER:-}}"
if [[ -z "$RUN_USER" || "$RUN_USER" == "root" ]]; then
  echo "Could not determine the target user. Re-run with: RUN_USER=<you> sudo $0" >&2
  exit 1
fi
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
export RUN_USER RUN_HOME

# tee all output to a timestamped logfile
LOGFILE="${LOGFILE:-/var/log/kali-t490s-$(date +%Y%m%d-%H%M%S).log}"
exec > >(tee -a "$LOGFILE") 2>&1

# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

# --- preflight checks -------------------------------------------------------
preflight() {
  hr; info "Preflight checks"
  local ok_all=1
  # OS
  if grep -qs '^ID=kali' /etc/os-release; then ok "OS: Kali Linux"; else
    warn "OS is not Kali (some Kali-specific packages may be missing)"; fi
  # arch
  local arch; arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
  if [[ "$arch" == "amd64" ]]; then ok "arch: amd64"; else warn "arch is '$arch' (kit targets amd64)"; fi
  # disk
  local avail; avail="$(df --output=avail -BG / 2>/dev/null | tail -1 | tr -dc '0-9')"
  if [[ -n "$avail" && "$avail" -ge 15 ]]; then ok "disk: ${avail}G free on /"; else
    warn "low disk: ${avail:-?}G free on / (full run wants ~15G+)"; fi
  # network (installs need it)
  if curl -fsI --max-time 8 https://http.kali.org >/dev/null 2>&1 \
     || ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then ok "network: reachable"; else
    err "no network — package installs will fail"; ok_all=0; fi
  hr
  [[ "$ok_all" -eq 1 ]]
}

if [[ "$CMD" == "doctor" ]]; then
  preflight && info "Preflight OK." || warn "Preflight found blocking issues."
  exit 0
fi

info "Provisioning Kali for user '$RUN_USER' (home: $RUN_HOME)"
info "Logging to $LOGFILE"
if ! preflight; then
  err "Preflight failed (see above). Fix the network and re-run, or 'doctor' to recheck."
  exit 1
fi

run_module() {
  local name="$1" file="$LIB_DIR/${name}.sh"
  [[ -f "$file" ]] || { warn "module not found: $name"; return 0; }
  hr; info "=== MODULE: $name ==="
  # shellcheck disable=SC1090
  source "$file"
}
for m in "${selected[@]}"; do run_module "$m"; done

# --- summary ----------------------------------------------------------------
hr
if [[ "${#WARNINGS[@]}" -eq 0 ]]; then
  ok "Completed with no warnings."
else
  warn "Completed with ${#WARNINGS[@]} warning(s):"
  printf '    - %s\n' "${WARNINGS[@]}"
fi
info "Full log: $LOGFILE"
cat <<'EOF'

Recommended next steps:
  * Reboot to pick up kernel/firmware/group changes (docker, libvirt, kvm).
  * Run the interactive checklist:  first-boot-checklist
  * Log out/in so your shell change (zsh) and new groups take effect.
EOF
