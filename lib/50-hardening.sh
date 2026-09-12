#!/usr/bin/env bash
# 50-hardening.sh — sensible defaults for a portable pentest/OSINT laptop.
# Nothing here is exotic; it's the baseline you'd want on a machine that
# leaves the house. Review each item — a few are informational.

# --- firewall: default-deny inbound -----------------------------------------
info "ufw firewall (default deny incoming, allow outgoing)"
apt_install ufw
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
ok "ufw enabled: $(ufw status | head -1)"

# --- SSH: ensure the daemon is NOT enabled by default -----------------------
# Kali ships ssh disabled; make it explicit and harden config if present.
if systemctl is-enabled ssh >/dev/null 2>&1; then
  warn "ssh service is enabled — disabling (re-enable manually if you need it)"
  systemctl disable --now ssh || true
fi
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  ok "sshd_config hardened (root login off, key-only) — takes effect if ssh is started"
fi

# --- MAC address randomization via NetworkManager ---------------------------
info "NetworkManager MAC randomization (wifi scan + per-connection random)"
cat > /etc/NetworkManager/conf.d/00-macrandomize.conf <<'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
systemctl reload NetworkManager 2>/dev/null || true
ok "MAC randomization configured (reconnect wifi to apply)"

# --- ensure NetworkManager owns wifi ----------------------------------------
# A minimal-installer wlan stanza in /etc/network/interfaces makes systemd run
# ifup@wlanX at boot, which starts its own wpa_supplicant and beats NM to the
# card — the card then shows 'unmanaged' and wifi dies once the desktop lands.
# Neutralize any such stanza (backup first) and stop the per-interface unit.
IFCFG=/etc/network/interfaces
if [[ -f "$IFCFG" ]] && grep -qsE '^[[:space:]]*(allow-hotplug|auto|iface)[[:space:]]+wl' "$IFCFG"; then
  info "neutralizing leftover ifupdown wlan stanza (conflicts with NetworkManager)"
  cp -a "$IFCFG" "${IFCFG}.kitbak-$(date +%s)"
  awk '
    /^[[:space:]]*(allow-hotplug|auto|iface)[[:space:]]+wl/ {print "#kit-disabled "$0; blk=1; next}
    blk==1 && /^[[:space:]]+[^[:space:]#]/               {print "#kit-disabled "$0; next}
    {blk=0; print}
  ' "$IFCFG" > "${IFCFG}.kit" && mv "${IFCFG}.kit" "$IFCFG"
  systemctl mask ifup@wlan0.service >/dev/null 2>&1 || true
  systemctl restart NetworkManager 2>/dev/null || true
  ok "wlan handed to NetworkManager (never run 'systemctl enable wpa_supplicant' on Kali)"
fi

# --- automatic security updates ---------------------------------------------
# NOTE: Kali is a rolling distro; unattended full upgrades can break tools.
# We enable download-only + security-ish behavior and leave install to you.
info "unattended-upgrades (download only; manual apply recommended on rolling)"
apt_install unattended-upgrades apt-listchanges
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "0";
EOF
note "auto-INSTALL left OFF for rolling stability. Run 'sudo apt full-upgrade' regularly."

# --- fail2ban (only meaningful if you ever expose a service) ----------------
apt_install fail2ban
systemctl enable fail2ban 2>/dev/null || true

# --- kernel/network sysctl hardening ----------------------------------------
info "sysctl hardening (rp_filter, martians, no source-routing)"
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
EOF
sysctl --system >/dev/null 2>&1 || true

# --- USBGuard (optional, informational) -------------------------------------
# detect the LUKS partition so the note shows the real device, not a guess
LUKSDEV="$(lsblk -rno NAME,FSTYPE 2>/dev/null | awk '$2=="crypto_LUKS"{print "/dev/"$1; exit}')"
cat <<EOF
${_c_yellow}[!]${_c_reset} Optional: 'sudo apt install usbguard' to whitelist USB devices
    (blocks rogue USB while unlocked). Not enabled here to avoid locking out
    your own peripherals on first boot.
${_c_yellow}[!]${_c_reset} LUKS: if you used full-disk encryption, consider a second keyslot for a
    backup passphrase (find your LUKS partition with: lsblk -f | grep crypto_LUKS):
      sudo cryptsetup luksAddKey ${LUKSDEV:-/dev/YOUR_LUKS_PARTITION}
EOF

ok "hardening module complete"
