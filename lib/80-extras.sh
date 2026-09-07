#!/usr/bin/env bash
# 80-extras.sh — Nerd Font (prompt glyphs), Flatpak/Flathub, Syncthing.

# --- Nerd Font so starship/tmux icons render --------------------------------
NF_VER="v3.3.0"
NF_DIR="/usr/local/share/fonts/JetBrainsMonoNerd"
if [[ ! -d "$NF_DIR" ]]; then
  info "installing JetBrainsMono Nerd Font"
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VER}/JetBrainsMono.zip" -o "$tmp/nf.zip"; then
    mkdir -p "$NF_DIR"
    unzip -oq "$tmp/nf.zip" -d "$NF_DIR" -x "*.md" "*.txt" || true
    fc-cache -f "$NF_DIR" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1
    ok "Nerd Font installed (set your terminal font to 'JetBrainsMono Nerd Font')"
  else
    warn "Nerd Font download failed"
  fi
  rm -rf "$tmp"
fi

# --- Flatpak + Flathub -------------------------------------------------------
info "Flatpak + Flathub remote"
apt_install flatpak
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
  && ok "Flathub remote added" || warn "could not add Flathub"
warn "log out/in (or reboot) so Flatpak apps appear in your menu + PATH"

# --- Syncthing (peer-to-peer sync across your homelab) ----------------------
info "Syncthing"
apt_install syncthing
# system-provided per-user template unit: syncthing@<user>.service
if systemctl enable --now "syncthing@${RUN_USER}" 2>/dev/null; then
  ok "syncthing running for $RUN_USER — web UI at http://127.0.0.1:8384"
else
  warn "could not enable syncthing@${RUN_USER}; start manually with that unit"
fi

cat <<EOF
${_c_blue}[*]${_c_reset} Syncthing UI: http://127.0.0.1:8384 — pair this laptop with your other
    machines to sync your Obsidian vault / notes without any cloud.
EOF

ok "extras module complete"
