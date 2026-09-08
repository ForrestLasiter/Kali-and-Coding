#!/usr/bin/env bash
# common.sh — shared helpers sourced by provision.sh and every module.
# Not meant to be run directly.

# sudo's secure_path often omits /usr/local/bin, so tools we install there
# (e.g. the Go symlink, starship) aren't found by `command -v` mid-run. Put
# them on PATH for every module. /usr/local/go/bin covers a raw Go install.
case ":$PATH:" in
  *:/usr/local/bin:*) ;;
  *) export PATH="/usr/local/sbin:/usr/local/bin:$PATH" ;;
esac
export PATH="$PATH:/usr/local/go/bin"

# Architecture, so download URLs adapt to amd64 / arm64 laptops.
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
case "$ARCH" in
  amd64) GOARCH=amd64; RUST_ARCH=x86_64  ;;
  arm64) GOARCH=arm64; RUST_ARCH=aarch64 ;;
  *)     GOARCH=amd64; RUST_ARCH=x86_64  ;;
esac
export ARCH GOARCH RUST_ARCH

# --- pretty output ----------------------------------------------------------
_c_reset=$'\033[0m'; _c_blue=$'\033[1;34m'; _c_yellow=$'\033[1;33m'
_c_red=$'\033[1;31m'; _c_green=$'\033[1;32m'
# WARNINGS collects every warn() message so provision.sh can print a summary.
WARNINGS=()
info()  { echo "${_c_blue}[*]${_c_reset} $*"; }
ok()    { echo "${_c_green}[+]${_c_reset} $*"; }
warn()  { WARNINGS+=("$*"); echo "${_c_yellow}[!]${_c_reset} $*" >&2; }
err()   { echo "${_c_red}[x]${_c_reset} $*" >&2; }
# note() — an intentional advisory ("here's what I did / FYI"), NOT a failure.
# Printed but deliberately kept out of the end-of-run warning tally.
note()  { echo "${_c_yellow}[i]${_c_reset} $*"; }
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

# Install packages, skipping any already installed. Resilient: if the batch
# install fails (usually because ONE package is missing/renamed on Kali rolling),
# retry each package individually so the available ones still get installed and
# only the truly-unavailable ones are warned about.
apt_install() {
  apt_refresh
  local to_install=()
  for pkg in "$@"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || to_install+=("$pkg")
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    ok "all requested packages already installed"
    return 0
  fi
  info "installing: ${to_install[*]}"
  if apt-get install -y --no-install-recommends "${to_install[@]}"; then
    return 0
  fi
  # batch failed — install one at a time so a single bad package can't block the rest
  info "batch install failed; retrying each package individually"
  local failed=()
  for pkg in "${to_install[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 && continue
    apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1 || failed+=("$pkg")
  done
  [[ ${#failed[@]} -gt 0 ]] && warn "unavailable on this Kali: ${failed[*]}"
  return 0
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

# --- install prebuilt binaries from a release archive -----------------------
# install_release <name> <url> <bin>...  — download a .tar.gz/.zip, find each
# named executable inside, and install it into /usr/local/bin.
install_release() {
  local name="$1" url="$2"; shift 2
  local bins=("$@")
  command -v "${bins[0]}" >/dev/null 2>&1 && { ok "$name already installed"; return 0; }
  local tmp; tmp="$(mktemp -d)"
  info "downloading $name release binary"
  if ! curl -fsSL "$url" -o "$tmp/a"; then warn "download failed: $name"; rm -rf "$tmp"; return 0; fi
  mkdir -p "$tmp/x"
  case "$url" in
    *.zip) unzip -qo "$tmp/a" -d "$tmp/x" 2>/dev/null || { warn "unzip failed: $name"; rm -rf "$tmp"; return 0; } ;;
    *)     tar -xf "$tmp/a" -C "$tmp/x" 2>/dev/null || { warn "extract failed: $name"; rm -rf "$tmp"; return 0; } ;;
  esac
  local b found
  for b in "${bins[@]}"; do
    found="$(find "$tmp/x" -type f -name "$b" | head -1)"
    if [[ -n "$found" ]]; then install -m 0755 "$found" "/usr/local/bin/$b" && ok "installed $b -> /usr/local/bin"; else
      warn "$b not found in $name archive"; fi
  done
  rm -rf "$tmp"
}

# install_gh_release_bin <name> <owner/repo> <asset-regex> <bin>...
# resolve the latest release's matching asset via the GitHub API, then install.
install_gh_release_bin() {
  local name="$1" repo="$2" pat="$3"; shift 3
  command -v "$1" >/dev/null 2>&1 && { ok "$name already installed"; return 0; }
  local url
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' | cut -d'"' -f4 \
        | grep -E "$pat" | head -1)"
  [[ -z "$url" ]] && { warn "no matching release asset for $name ($pat)"; return 0; }
  install_release "$name" "$url" "$@"
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
