#!/usr/bin/env bash
# 40-productivity.sh — notes, password manager, media, office, screenshots.

# --- from Kali/Debian repos --------------------------------------------------
info "productivity & media packages"
apt_install \
  keepassxc \
  vlc mpv \
  flameshot \
  libreoffice \
  gimp \
  obs-studio \
  copyq \
  gnome-screenshot \
  fonts-firacode fonts-jetbrains-mono

# --- Obsidian (.deb from GitHub releases) -----------------------------------
OBSIDIAN_VER="1.8.7"
if ! dpkg -s obsidian >/dev/null 2>&1; then
  install_deb "obsidian" \
    "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VER}/obsidian_${OBSIDIAN_VER}_amd64.deb"
fi

# --- Bitwarden CLI via pipx-alternative (snap-free): use the .deb? -----------
# Bitwarden desktop ships as .deb from their site; install if desired:
BW_VER="2025.1.1"
if ! dpkg -s bitwarden >/dev/null 2>&1; then
  install_deb "bitwarden" \
    "https://github.com/bitwarden/clients/releases/download/desktop-v${BW_VER}/Bitwarden-${BW_VER}-amd64.deb" \
    || warn "Bitwarden desktop optional — skip if version bumped"
fi

ok "productivity module complete"
