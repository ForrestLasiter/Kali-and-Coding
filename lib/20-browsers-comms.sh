#!/usr/bin/env bash
# 20-browsers-comms.sh — browsers, secure messaging, mail, VPN clients.

# --- Firefox ESR ships on Kali; add a hardening user.js reminder ------------
apt_install firefox-esr thunderbird
info "Firefox: a hardening user.js template is in dotfiles/firefox-user.js (see README)"

# --- Brave (official apt repo) ----------------------------------------------
add_apt_repo "brave-browser" \
  "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
  "deb [signed-by=KEYRING arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"
# Note: Brave's key URL serves an already-dearmored keyring; re-dearmor is
# harmless. If apt complains, delete /usr/share/keyrings/brave-browser.gpg and
# re-fetch with: curl ... -o /usr/share/keyrings/brave-browser.gpg
apt_install brave-browser

# --- Signal (official apt repo) ---------------------------------------------
add_apt_repo "signal-desktop" \
  "https://updates.signal.org/desktop/apt/keys.asc" \
  "deb [arch=amd64 signed-by=KEYRING] https://updates.signal.org/desktop/apt xenial main"
apt_install signal-desktop

# --- Element (Matrix) via official apt repo ---------------------------------
add_apt_repo "element-io" \
  "https://packages.element.io/debian/element-io-archive-keyring.gpg" \
  "deb [signed-by=KEYRING] https://packages.element.io/debian/ default main"
apt_install element-desktop

# --- VPN clients -------------------------------------------------------------
# WireGuard is the primary client (also used by your homevpn hub).
apt_install wireguard wireguard-tools openvpn network-manager-openvpn-gnome resolvconf

# ProtonVPN official repo (optional GUI). Uses a versioned release .deb that
# registers the repo, then installs the app.
if ! command -v protonvpn-app >/dev/null 2>&1 && ! dpkg -s proton-vpn-gnome-desktop >/dev/null 2>&1; then
  info "ProtonVPN repo + app"
  install_deb "protonvpn-repo" \
    "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb"
  APT_UPDATED=0
  apt_install proton-vpn-gnome-desktop || warn "ProtonVPN app not installed (check repo release version)"
fi

ok "browsers & comms module complete"
