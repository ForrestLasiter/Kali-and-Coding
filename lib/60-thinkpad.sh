#!/usr/bin/env bash
# 60-thinkpad.sh — T490s hardware bring-up: power, firmware, thermals, fingerprint.
# The T490s (8th-gen Whiskey Lake i7, Intel UHD 620, Intel 9560 wifi) is fully
# supported by the stock kernel — this module is about battery life and firmware,
# not missing drivers.

# --- microcode + firmware update daemon -------------------------------------
info "Intel microcode + fwupd (LVFS firmware updates)"
apt_install intel-microcode fwupd

# --- power management: TLP (ThinkPad-friendly) ------------------------------
# Do NOT install both TLP and power-profiles-daemon — they conflict.
info "TLP power management (with ThinkPad battery-threshold support)"
if dpkg -s power-profiles-daemon >/dev/null 2>&1; then
  apt-get purge -y power-profiles-daemon || true
fi
apt_install tlp tlp-rdw
systemctl enable --now tlp 2>/dev/null || true

# ThinkPad battery charge thresholds (extends battery lifespan). The T490s
# supports start/stop charge thresholds via the natacpi/tp_smapi interface.
mkdir -p /etc/tlp.d
cat > /etc/tlp.d/10-thinkpad-battery.conf <<'EOF'
# Charge to 80%, start charging below 75% — good for a laptop mostly on AC.
# Comment these out if you want full-charge-before-travel behavior.
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
EOF
tlp start >/dev/null 2>&1 || true
ok "TLP configured (charge thresholds 75/80 — edit /etc/tlp.d/10-thinkpad-battery.conf)"

# --- thermal management ------------------------------------------------------
apt_install thermald
systemctl enable --now thermald 2>/dev/null || true

# --- fingerprint reader (T490s = Synaptics/Validity, works with libfprint) --
info "fingerprint reader support (fprintd)"
apt_install fprintd libpam-fprintd
cat <<EOF
${_c_blue}[*]${_c_reset} To enroll a fingerprint: run 'fprintd-enroll' as your user, then
    'sudo pam-auth-update' and enable 'Fingerprint authentication'.
    Note: some T490s units ship a reader model not yet in libfprint — if
    enrollment fails, check: fprintd-list \$USER  and  lsusb | grep -i finger
EOF

# --- laptop niceties ---------------------------------------------------------
apt_install \
  powertop \
  acpi acpid \
  brightnessctl \
  bluez blueman \
  libinput-tools

# Intel GPU: enable GuC/HuC firmware loading for better power/perf on UHD 620.
if [[ ! -f /etc/modprobe.d/i915.conf ]]; then
  echo "options i915 enable_guc=3" > /etc/modprobe.d/i915.conf
  info "i915 GuC/HuC enabled (update-initramfs to apply)"
  update-initramfs -u >/dev/null 2>&1 || warn "update-initramfs failed; run manually"
fi

cat <<EOF
${_c_blue}[*]${_c_reset} After reboot, run 'sudo fwupdmgr refresh && fwupdmgr get-updates'
    to pull BIOS/firmware updates from LVFS for the T490s.
EOF

ok "thinkpad module complete"
