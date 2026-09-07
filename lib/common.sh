#!/usr/bin/env bash
# common.sh — shared helpers sourced by provision.sh and every module.
# Not meant to be run directly.

# --- pretty output ----------------------------------------------------------
_c_reset=$'\033[0m'; _c_blue=$'\033[1;34m'; _c_yellow=$'\033[1;33m'
_c_red=$'\033[1;31m'; _c_green=$'\033[1;32m'
info()  { echo "${_c_blue}[*]${_c_reset} $*"; }
ok()    { echo "${_c_green}[+]${_c_reset} $*"; }
warn()  { echo "${_c_yellow}[!]${_c_reset} $*" >&2; }
err()   { echo "${_c_red}[x]${_c_reset} $*" >&2; }
hr()    { printf '%s\n' "----------------------------------------------------------------------"; }

# --- run a command as the target (non-root) user ----------------------------
as_user() {
  sudo -u "$RUN_USER" -H bash -lc "$*"
}

# --- apt helpers ------------------------------------------------------------
APT_UPDATED=0
apt_refresh() {
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    info "apt-get update"
    apt-get update -qq
    APT_UPDATED=1
  fi
}

# Install packages, skipping any already installed. Missing ones are warned,
# not fatal (Kali rolling occasionally renames packages).
apt_install() {
  apt_refresh
  local to_install=()
  for pkg in "$@"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      continue
    fi
    to_install+=("$pkg")
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    ok "all requested packages already installed"
    return 0
  fi
  info "installing: ${to_install[*]}"
  apt-get install -y --no-install-recommends "${to_install[@]}" \
    || warn "one or more packages failed to install: ${to_install[*]}"
}

# Install every package listed (one per line, # comments allowed) in a file.
apt_install_file() {
  local file="$1"
  [[ -f "$file" ]] || { warn "package file missing: $file"; return 0; }
  mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$file" | awk '{print $1}')
  [[ ${#pkgs[@]} -gt 0 ]] && apt_install "${pkgs[@]}"
}

# --- third-party apt repo helper -------------------------------------------
# add_apt_repo <name> <key-url> <repo-line-with-signed-by-placeholder>
# Use the literal string KEYRING in the repo line; it is substituted.
add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  local keyring="/usr/share/keyrings/${name}.gpg"
  local listfile="/etc/apt/sources.list.d/${name}.list"
  if [[ -f "$listfile" && -f "$keyring" ]]; then
    ok "apt repo '$name' already configured"
    return 0
  fi
  info "adding apt repo: $name"
  curl -fsSL "$key_url" | gpg --dearmor -o "$keyring" \
    || { err "failed to fetch key for $name"; return 1; }
  chmod 0644 "$keyring"
  echo "${repo_line/KEYRING/$keyring}" > "$listfile"
  APT_UPDATED=0  # force a refresh next install
}

# --- download a .deb and install it ----------------------------------------
install_deb() {
  local name="$1" url="$2"
  local tmp; tmp="$(mktemp -d)"
  info "downloading $name .deb"
  if curl -fsSL "$url" -o "$tmp/pkg.deb"; then
    apt-get install -y "$tmp/pkg.deb" || warn "failed to install $name"
  else
    warn "could not download $name from $url"
  fi
  rm -rf "$tmp"
}
