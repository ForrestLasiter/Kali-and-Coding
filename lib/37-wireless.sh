#!/usr/bin/env bash
# 37-wireless.sh — wireless auditing + the DKMS driver for common external
# adapters. Most laptops' internal Intel/Realtek wifi can't do injection/monitor
# mode well, so this shines with an external adapter — an Alfa AWUS036ACM
# (MT7612U, no driver needed) or an RTL8812AU-based stick (uses the DKMS driver).
#
# Only test networks you own or are authorized to assess.

# --- kernel headers (DKMS needs them to build the driver) -------------------
info "kernel headers for DKMS"
apt_install "linux-headers-$(uname -r)" linux-headers-amd64

# --- RTL8812AU/8814AU/8821AU driver (many Alfa/USB adapters) ----------------
info "realtek-rtl88xxau DKMS driver (external adapter injection support)"
apt_install realtek-rtl88xxau-dkms || warn "rtl88xxau dkms failed (MT7612U adapters need no driver)"

# --- wireless auditing tooling ----------------------------------------------
info "wireless auditing tools"
apt_install \
  aircrack-ng \
  kismet \
  wifite \
  bettercap \
  hcxdumptool hcxtools \
  reaver bully \
  mdk4 \
  airgeddon

cat <<EOF
${_c_blue}[*]${_c_reset} After plugging an adapter: 'iw dev' lists it, then
    'sudo airmon-ng start wlanX' for monitor mode. rtl88xxau needs a reboot
    after install so DKMS loads the built module.
EOF

ok "wireless module complete"
