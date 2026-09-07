#!/usr/bin/env bash
#
# provision.sh — Post-install provisioning for Kali Linux on a Lenovo ThinkPad T490s
#
# Run this AFTER a fresh Kali install (see README.md for the install walkthrough).
# It is idempotent: safe to re-run, and you can run individual modules.
#
# Usage:
#   sudo ./provision.sh              # run every module in order
#   sudo ./provision.sh all          # same as above
#   sudo ./provision.sh 10 30        # run only modules 10-dev and 30-osint
#   sudo ./provision.sh list         # list available modules
#   RUN_USER=forrest sudo ./provision.sh   # override the target (non-root) user
#
set -euo pipefail

# --- resolve paths ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
export SCRIPT_DIR LIB_DIR
export DEBIAN_FRONTEND=noninteractive

# --- must be root -----------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must run as root. Use: sudo $0 $*" >&2
  exit 1
fi

# --- figure out the real (non-root) user we're provisioning for -------------
# When invoked with sudo, SUDO_USER is the human. Allow override via RUN_USER.
RUN_USER="${RUN_USER:-${SUDO_USER:-}}"
if [[ -z "$RUN_USER" || "$RUN_USER" == "root" ]]; then
  echo "Could not determine the target user. Re-run with: RUN_USER=<you> sudo $0" >&2
  exit 1
fi
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
export RUN_USER RUN_HOME

# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

# --- module registry (ordered) ---------------------------------------------
MODULES=(
  "00-base"
  "10-dev"
  "20-browsers-comms"
  "30-osint"
  "40-productivity"
  "50-hardening"
  "60-thinkpad"
  "90-dotfiles"
)

list_modules() {
  echo "Available modules:"
  for m in "${MODULES[@]}"; do
    printf "  %s\n" "$m"
  done
}

run_module() {
  local name="$1"
  local file="$LIB_DIR/${name}.sh"
  [[ -f "$file" ]] || { warn "module not found: $name"; return 0; }
  hr
  info "=== MODULE: $name ==="
  # shellcheck disable=SC1090
  source "$file"
}

# --- argument handling ------------------------------------------------------
case "${1:-all}" in
  list)
    list_modules
    exit 0
    ;;
  all)
    info "Provisioning Kali for user '$RUN_USER' (home: $RUN_HOME)"
    for m in "${MODULES[@]}"; do run_module "$m"; done
    ;;
  *)
    # run only the modules whose numeric prefix matches an argument
    for arg in "$@"; do
      match=""
      for m in "${MODULES[@]}"; do
        [[ "$m" == "${arg}"* ]] && match="$m" && run_module "$m"
      done
      [[ -z "$match" ]] && warn "no module matched '$arg'"
    done
    ;;
esac

hr
info "Done. Recommended next steps:"
cat <<'EOF'
  * Reboot to pick up kernel/firmware/group changes (docker group, etc.).
  * Run `fwupdmgr get-updates` to check for firmware updates on the T490s.
  * Log out/in so your shell change (zsh) and docker group take effect.
  * Review lib/50-hardening.sh output — some items are informational only.
EOF
