#!/usr/bin/env bash
# 60-hardware.sh — laptop hardware bring-up, auto-detected for ANY machine.
# Detects CPU vendor, GPU, and laptop vendor, then applies the right microcode,
# GPU firmware/driver, power tuning, and (where the firmware supports it)
# battery charge thresholds. Universal bits — fwupd, TLP, powertop, fingerprint,
# bluetooth — always run. Tunables come from config.sh (BAT_*/INSTALL_GPU_DRIVER).

# --- detect -----------------------------------------------------------------
CPU_VENDOR="$(grep -m1 '^vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"
SYS_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown)"
PRODUCT="$(cat /sys/class/dmi/id/product_version 2>/dev/null || echo '')"
GPU="$(lspci 2>/dev/null | grep -iE 'vga|3d controller|display' || true)"
info "detected — CPU: ${CPU_VENDOR:-unknown} | vendor: ${SYS_VENDOR} ${PRODUCT}"
info "GPU: ${GPU:-unknown}"

# --- microcode (CPU-vendor specific) + Intel thermal ------------------------
case "$CPU_VENDOR" in
  GenuineIntel)
    apt_install intel-microcode thermald
    systemctl enable --now thermald 2>/dev/null || true ;;
  AuthenticAMD)
    apt_install amd64-microcode ;;
  *)
    note "unknown CPU vendor '${CPU_VENDOR:-?}' — skipping microcode" ;;
esac

# --- firmware updates (universal) -------------------------------------------
apt_install fwupd

# --- GPU drivers / firmware (detected) --------------------------------------
if [[ "${INSTALL_GPU_DRIVER:-auto}" != "none" ]]; then
  # match on lspci vendor strings with word boundaries — NOT loose substrings
  # (e.g. bare "ati" would match "compatible" and mis-detect a VMware GPU as AMD)
  if grep -qiE 'intel corporation|\bintel\b' <<<"$GPU"; then
    info "Intel GPU: VA driver + GuC/HuC firmware loading"
    apt_install intel-media-va-driver
    if [[ ! -f /etc/modprobe.d/i915.conf ]]; then
      echo "options i915 enable_guc=3" > /etc/modprobe.d/i915.conf
      update-initramfs -u >/dev/null 2>&1 || warn "update-initramfs failed; run it manually"
    fi
  elif grep -qiE 'advanced micro devices|amd/ati|\bradeon\b|\bamd\b' <<<"$GPU"; then
    info "AMD GPU: firmware + VA drivers"
    apt_install firmware-amd-graphics mesa-va-drivers
  elif grep -qiE '\bnvidia\b' <<<"$GPU"; then
    if [[ "${INSTALL_GPU_DRIVER}" == "nvidia" ]]; then
      info "NVIDIA GPU: installing proprietary driver"
      apt_install nvidia-driver nvidia-settings
    else
      note "NVIDIA GPU detected — proprietary driver NOT installed (can break boot if misconfigured). Re-run with INSTALL_GPU_DRIVER=nvidia, or: sudo apt install nvidia-driver"
    fi
  fi
fi

# --- power management: TLP (universal; conflicts with power-profiles-daemon) -
if dpkg -s power-profiles-daemon >/dev/null 2>&1; then
  apt-get purge -y power-profiles-daemon || true
fi
apt_install tlp tlp-rdw
systemctl enable --now tlp 2>/dev/null || true

# --- battery charge thresholds — only where the firmware exposes them --------
BAT="$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)"
if [[ -n "$BAT" && ( -e "$BAT/charge_control_end_threshold" || -e "$BAT/charge_stop_threshold" ) ]]; then
  install -d /etc/tlp.d
  cat > /etc/tlp.d/10-battery.conf <<EOF
# Charge thresholds extend battery lifespan on machines that support them.
START_CHARGE_THRESH_BAT0=${BAT_START:-75}
STOP_CHARGE_THRESH_BAT0=${BAT_STOP:-80}
EOF
  tlp start >/dev/null 2>&1 || true
  ok "battery thresholds set ${BAT_START:-75}/${BAT_STOP:-80} (edit /etc/tlp.d/10-battery.conf)"
elif [[ -n "$BAT" ]]; then
  note "battery present but firmware exposes no charge-threshold control — skipping"
else
  note "no battery detected (desktop/VM?) — skipping charge thresholds"
fi

# --- fingerprint reader (libfprint works across most vendors) ---------------
info "fingerprint reader support (fprintd)"
apt_install fprintd libpam-fprintd
note "enroll a print with 'fprintd-enroll', then 'sudo pam-auth-update' to use it for login/sudo"

# --- universal laptop niceties ----------------------------------------------
apt_install powertop acpi acpid brightnessctl bluez blueman libinput-tools

cat <<EOF
${_c_blue}[*]${_c_reset} After reboot: 'sudo fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update'
    pulls BIOS/firmware from LVFS for supported machines (most modern laptops).
EOF

ok "hardware module complete"
