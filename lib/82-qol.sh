#!/usr/bin/env bash
# 82-qol.sh — quality-of-life: modern CLI extras, terminal file managers, a
# better terminal, launcher/compositor, and XFCE desktop niceties.

# apt first; fall back to cargo/go (installed by modules 10/12) if the repo
# doesn't carry the tool.
apt_or_cargo() { # <binary> <apt-pkg> <cargo-crate>
  apt_install "$2"
  command -v "$1" >/dev/null 2>&1 && return 0
  as_user "source \$HOME/.cargo/env 2>/dev/null; cargo install $3" \
    || warn "could not install $1 (apt + cargo both failed)"
}
apt_or_go() { # <binary> <apt-pkg> <go-module>
  apt_install "$2"
  command -v "$1" >/dev/null 2>&1 && return 0
  as_user "export PATH=\$PATH:/usr/local/go/bin GOPATH=\$HOME/go; go install $3" \
    || warn "could not install $1 (apt + go both failed)"
}

# =============================================================================
# Modern CLI upgrades
# =============================================================================
info "modern CLI upgrades (duf, dust, procs, sd, glow, fastfetch)"
apt_install fastfetch
apt_or_go   duf   duf     "github.com/muesli/duf@latest"
apt_or_cargo dust du-dust du-dust
apt_or_cargo procs procs  procs
apt_or_cargo sd    sd     sd
apt_or_go   glow  glow    "github.com/charmbracelet/glow@latest"

# =============================================================================
# Terminal file managers
# =============================================================================
info "terminal file managers (yazi + nnn)"
apt_install nnn
# yazi: prebuilt binary (yazi + its `ya` helper), no cargo compile
install_gh_release_bin yazi sxyazi/yazi 'yazi-x86_64-unknown-linux-gnu\.zip$' yazi ya

# =============================================================================
# Cheatsheets + command correction
# =============================================================================
info "navi (cheatsheets) + thefuck (command correction)"
apt_install thefuck
# navi: prebuilt binary (asset name carries the version, so match by suffix)
install_gh_release_bin navi denisidoro/navi 'x86_64-unknown-linux-musl\.tar\.gz$' navi

# =============================================================================
# Better terminal emulator
# =============================================================================
info "kitty terminal"
apt_install kitty

# =============================================================================
# Desktop QoL (XFCE)
# =============================================================================
info "desktop QoL (launcher, compositor, automount, night light, theming, utils)"
apt_install \
  rofi picom \
  udiskie gammastep geoclue-2.0 \
  papirus-icon-theme arc-theme \
  zathura zathura-pdf-poppler peek xarchiver gpick

# --- autostart: udiskie (USB automount tray) --------------------------------
AUTOSTART="$RUN_HOME/.config/autostart"
install -d -o "$RUN_USER" -g "$RUN_USER" "$AUTOSTART"
cat > "$AUTOSTART/udiskie.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=udiskie
Comment=Automount removable media
Exec=udiskie --tray
X-GNOME-Autostart-enabled=true
EOF
chown "$RUN_USER:$RUN_USER" "$AUTOSTART/udiskie.desktop"

# --- night light: gammastep via geoclue, autostarted ------------------------
install -d -o "$RUN_USER" -g "$RUN_USER" "$RUN_HOME/.config/gammastep"
cat > "$RUN_HOME/.config/gammastep/config.ini" <<'EOF'
[general]
temp-day=6500
temp-night=3800
location-provider=geoclue2
adjustment-method=randr
EOF
chown -R "$RUN_USER:$RUN_USER" "$RUN_HOME/.config/gammastep"
cat > "$AUTOSTART/gammastep.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=gammastep
Comment=Night light (warm screen after dark)
Exec=gammastep
X-GNOME-Autostart-enabled=true
EOF
chown "$RUN_USER:$RUN_USER" "$AUTOSTART/gammastep.desktop"

cat <<EOF
${_c_blue}[*]${_c_reset} QoL notes:
    - kitty is installed; set it as default in XFCE > Default Applications,
      or run it directly. yazi: type 'y' to browse (cd's on exit).
    - rofi launcher: bind a key in Settings > Keyboard > Shortcuts, e.g.
        rofi -show drun    (app launcher)   /   rofi -show window
    - picom (compositor): FIRST disable XFCE's built-in compositor
      (Settings > Window Manager Tweaks > Compositor > uncheck), THEN add
      'picom' to autostart. Left off by default to avoid a double-compositor.
    - Theming: apply Arc + Papirus in Settings > Appearance / Window Manager.
    - gammastep night light autostarts via geoclue; if location fails, set a
      manual 'lat:lon' in ~/.config/gammastep/config.ini (location-provider=manual).
EOF

ok "qol module complete"
