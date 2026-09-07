#!/usr/bin/env bash
# 15-vmlab.sh — KVM/QEMU virtualization lab for isolated test VMs.
# 16 GB RAM comfortably runs a couple of guests (Windows AD target, a
# vulnerable box, a detonation sandbox).

info "KVM/QEMU + libvirt + virt-manager"
apt_install \
  qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virt-manager virtinst \
  bridge-utils dnsmasq-base \
  ovmf swtpm            # UEFI + TPM emulation (needed for Windows 11 guests)

# check virtualization is actually available (Intel VT-x must be on in BIOS)
if ! grep -qE 'vmx|svm' /proc/cpuinfo; then
  warn "CPU virtualization flags not found — enable Intel VT-x in the T490s BIOS"
  warn "(BIOS: Security -> Virtualization -> Intel VT / VT-d = Enabled)"
fi

systemctl enable --now libvirtd 2>/dev/null || warn "could not enable libvirtd"

# put the user in the groups that skip the sudo/password prompt for VMs
for grp in libvirt kvm; do
  if ! id -nG "$RUN_USER" | grep -qw "$grp"; then
    usermod -aG "$grp" "$RUN_USER" && ok "added $RUN_USER to '$grp' (re-login required)"
  fi
done

# make sure the default NAT network is present & autostarts
if virsh net-info default >/dev/null 2>&1; then
  virsh net-autostart default >/dev/null 2>&1 || true
  virsh net-start default >/dev/null 2>&1 || true
  ok "libvirt 'default' NAT network set to autostart"
else
  warn "libvirt 'default' network missing — create one in virt-manager"
fi

ok "vmlab module complete"
