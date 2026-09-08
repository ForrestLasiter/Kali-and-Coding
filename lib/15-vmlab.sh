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
  warn "CPU virtualization flags not found — enable CPU virtualization in your BIOS/UEFI"
  warn "(look for Intel VT-x/VT-d or AMD SVM under Security/CPU)"
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

# --- Whonix import helper (Gateway + Workstation, KVM) ----------------------
# We do NOT auto-download Whonix: the bundle is large and MUST be signature-
# verified by you first. This helper automates the tedious libvirt import once
# you've downloaded, verified, and extracted the official KVM bundle.
cat > /usr/local/bin/whonix-import <<'EOF'
#!/usr/bin/env bash
# Import Whonix Gateway + Workstation (KVM) from an extracted, VERIFIED bundle.
#
# DO THIS FIRST (manually — it involves signature verification):
#   1. Get the Whonix KVM build + its .asc signature: https://www.whonix.org/wiki/KVM
#   2. Import the Whonix signing key and VERIFY (do not proceed unless GOOD):
#        gpg --import <whonix-signing-key.asc>
#        gpg --verify Whonix-*.libvirt.xz.asc Whonix-*.libvirt.xz
#   3. Extract:  tar -xvf Whonix-*.libvirt.xz
# THEN:  sudo whonix-import <dir-with-extracted-xml-and-qcow2>
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
dir="${1:?usage: whonix-import <extracted-whonix-dir>}"
cd "$dir"
VIRSH="virsh -c qemu:///system"
IMG=/var/lib/libvirt/images
shopt -s nullglob

# 1) place disk images where the domain XML expects them
for q in *.qcow2; do
  if [[ -f "$IMG/$q" ]]; then echo "[=] $IMG/$q already present"; else
    echo "[*] copying $q -> $IMG/"; cp --reflink=auto "$q" "$IMG/"; fi
done

# 2) define + start the Whonix virtual networks (external, then internal)
for netxml in Whonix_external*.xml Whonix_internal*.xml; do
  [[ -f "$netxml" ]] || continue
  echo "[*] net-define $netxml"; $VIRSH net-define "$netxml" || echo "[=] already defined"
done
for net in Whonix-External Whonix-Internal; do
  $VIRSH net-autostart "$net" 2>/dev/null || true
  $VIRSH net-start "$net" 2>/dev/null || echo "[=] $net already active"
done

# 3) define the domains (VMs)
for domxml in Whonix-Gateway*.xml Whonix-Workstation*.xml; do
  [[ -f "$domxml" ]] || continue
  echo "[*] define $domxml"; $VIRSH define "$domxml" || echo "[=] already defined"
done

echo
echo "[+] Whonix imported. Exact VM names: virsh -c qemu:///system list --all"
echo "    Start the GATEWAY first, then the WORKSTATION, then use virt-manager:"
echo "      virsh -c qemu:///system start <Whonix-Gateway-name>"
echo "      virsh -c qemu:///system start <Whonix-Workstation-name>"
EOF
chmod +x /usr/local/bin/whonix-import
ok "installed helper: whonix-import (see docs/ANONYMITY.md for the verify-first flow)"

ok "vmlab module complete"
