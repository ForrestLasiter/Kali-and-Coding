#!/usr/bin/env bash
# 95-firstboot.sh — install an interactive checklist for the post-install
# manual steps (firmware, fingerprint, snapshots, leak tests) so nothing gets
# forgotten after the automated run.

cat > /usr/local/bin/first-boot-checklist <<'EOF'
#!/usr/bin/env bash
# Interactive walk-through of the manual steps the provisioner can't do for you.
set -uo pipefail
b=$'\033[1;34m'; g=$'\033[1;32m'; y=$'\033[1;33m'; z=$'\033[0m'
ask(){ printf "%s[?]%s %s [y/N] " "$y" "$z" "$1"; read -r a; [[ "$a" =~ ^[Yy] ]]; }
say(){ printf "%s[*]%s %s\n" "$b" "$z" "$1"; }
done_(){ printf "%s[+]%s %s\n" "$g" "$z" "$1"; }

say "First-boot checklist"
echo

if ask "Check & apply firmware updates (fwupd / LVFS)?"; then
  sudo fwupdmgr refresh || true; sudo fwupdmgr get-updates || true
  ask "Apply available firmware updates now?" && sudo fwupdmgr update || true
  done_ "firmware step done"
fi

if ask "Enroll a fingerprint now?"; then
  fprintd-enroll || true
  say "Enable it for login/sudo: sudo pam-auth-update  (tick Fingerprint)"
fi

if ask "Set up Timeshift snapshots (recommended on rolling Kali)?"; then
  say "Launch Timeshift, pick RSYNC mode + a target, then take a first snapshot."
  command -v timeshift-gtk >/dev/null && (timeshift-gtk &) || sudo timeshift --create --comments "first boot" || true
fi

if ask "Run connectivity + leak sanity checks?"; then
  echo "  public IP:"; curl -s https://ifconfig.me; echo
  say "DNS leak test: https://dnsleaktest.com   Tor check: https://check.torproject.org"
fi

echo
done_ "Checklist complete. Reboot if you changed firmware or enrolled a fingerprint."
EOF
chmod +x /usr/local/bin/first-boot-checklist
ok "installed: first-boot-checklist (run it after your first reboot)"

ok "firstboot module complete"
