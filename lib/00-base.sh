#!/usr/bin/env bash
# 00-base.sh — full upgrade + core CLI tooling + metapackages.
# Sourced by provision.sh (common.sh already loaded).

info "Full system upgrade (kali-rolling)"
apt_refresh
apt-get -y full-upgrade || warn "full-upgrade reported errors"

info "Core build & fetch tooling"
apt_install \
  curl wget git ca-certificates gnupg lsb-release apt-transport-https \
  build-essential pkg-config software-properties-common \
  unzip p7zip-full xz-utils zstd \
  jq yq htop btop tree ncdu \
  net-tools dnsutils whois nmap tcpdump \
  vim neovim less man-db bash-completion \
  python3 python3-pip python3-venv pipx

# Kali metapackages. kali-linux-default is installed on standard ISOs; this line
# ensures it's present and adds the top-10 + headless bundles. Comment out any
# you don't want — kali-linux-large is ~big.
info "Kali tool metapackages"
apt_install kali-linux-default kali-tools-top10

ok "base module complete"
