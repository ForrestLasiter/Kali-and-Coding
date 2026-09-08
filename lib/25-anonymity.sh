#!/usr/bin/env bash
# 25-anonymity.sh — Tor, proxying, leak prevention, anti-forensics, and
# de-fingerprinted browsing. Complements a self-hosted VPN / Whonix workflow.
#
# READ docs/ANONYMITY.md first. Key truth: real anonymity comes from
# COMPARTMENTALIZATION (Whonix VMs / Tails), not from tools bolted onto a
# persistent, identified daily-driver. The tools below reduce passive leaks
# and forensic traces — they do not make this laptop "anonymous".
#
# Several changes here alter networking/logging. Each is reversible; the
# revert steps are in docs/ANONYMITY.md.

# =============================================================================
# Tor, proxying, metadata hygiene (base)
# =============================================================================
info "Tor, proxychains, torsocks, metadata scrubbing"
apt_install \
  tor torsocks proxychains4 mat2 torbrowser-launcher

PCONF="/etc/proxychains4.conf"
if [[ -f "$PCONF" ]]; then
  grep -q '^socks5\s\+127.0.0.1\s\+9050' "$PCONF" || \
    echo "socks5  127.0.0.1 9050" >> "$PCONF"
fi

# =============================================================================
# Encrypted DNS (dnscrypt-proxy) — DNS is the #1 deanonymizing leak
# =============================================================================
info "dnscrypt-proxy (encrypted DNS over HTTPS/TLS)"
apt_install dnscrypt-proxy
DCP_TOML="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
if [[ -f "$DCP_TOML" ]]; then
  # listen locally on :53 and prefer encrypted, no-log, DNSSEC resolvers
  sed -i "s|^listen_addresses =.*|listen_addresses = ['127.0.0.1:53']|" "$DCP_TOML"
  sed -i "s|^require_dnssec =.*|require_dnssec = true|" "$DCP_TOML"
  sed -i "s|^require_nolog =.*|require_nolog = true|"   "$DCP_TOML"
  sed -i "s|^require_nofilter =.*|require_nofilter = true|" "$DCP_TOML"
  # Debian ships socket-activated on 127.0.2.1; switch to a plain service on :53
  systemctl disable --now dnscrypt-proxy.socket 2>/dev/null || true
  systemctl enable  --now dnscrypt-proxy.service 2>/dev/null || warn "dnscrypt-proxy service failed to start"
  # force NetworkManager to use the local resolver instead of DHCP-provided DNS
  cat > /etc/NetworkManager/conf.d/10-dnscrypt.conf <<'EOF'
[global-dns-domain-*]
servers=127.0.0.1
EOF
  systemctl reload NetworkManager 2>/dev/null || true
  ok "dnscrypt-proxy on 127.0.0.1:53 (revert: rm the NM conf + re-enable .socket)"
else
  warn "dnscrypt-proxy config not found; skipping DNS rewire"
fi

# =============================================================================
# IPv6 leak guard — most consumer VPN/Tor paths are IPv4; kill v6 to be safe
# =============================================================================
info "disabling IPv6 (prevents leaks around IPv4-only VPN/Tor)"
cat > /etc/sysctl.d/99-privacy-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sysctl --system >/dev/null 2>&1 || true
warn "IPv6 off system-wide. If a network needs v6, delete /etc/sysctl.d/99-privacy-ipv6.conf"

# =============================================================================
# Mullvad Browser — Tor-Browser-grade anti-fingerprinting, over VPN/direct
# =============================================================================
add_apt_repo "mullvad" \
  "https://repository.mullvad.net/deb/mullvad-keyring.asc" \
  "deb [signed-by=KEYRING arch=amd64] https://repository.mullvad.net/deb/stable stable main"
apt_install mullvad-browser

# =============================================================================
# System-wide Tor routing (kalitorify) — CONVENIENCE, NOT LEAK-PROOF
# =============================================================================
info "kalitorify (transparent Tor routing) — see caveats"
apt_install kalitorify || warn "kalitorify not in repo (Whonix/Tails are the robust path)"

# =============================================================================
# Anti-forensics — BleachBit + secure-delete, plus a wipe-traces helper
# =============================================================================
info "anti-forensics tooling (bleachbit, secure-delete)"
apt_install bleachbit secure-delete
cat > /usr/local/bin/wipe-traces <<'EOF'
#!/usr/bin/env bash
# Clean local traces: caches, tmp, trash, recent docs, thumbnails, shell
# history. Run as your normal user. Review before relying on it for OPSEC.
set -euo pipefail
command -v bleachbit >/dev/null && bleachbit -c \
  system.cache system.tmp system.trash system.recent_documents 2>/dev/null || true
rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
: > "$HOME/.zsh_history" 2>/dev/null || true
: > "$HOME/.bash_history" 2>/dev/null || true
command -v history >/dev/null && history -c 2>/dev/null || true
echo "traces cleaned — open a new shell so history is fresh."
EOF
chmod +x /usr/local/bin/wipe-traces
ok "installed helper: wipe-traces (run as your user)"

# =============================================================================
# Logs in RAM — journald volatile (gone on reboot)
# =============================================================================
info "journald -> volatile (logs in RAM only)"
install -d /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-volatile.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=64M
EOF
systemctl restart systemd-journald 2>/dev/null || true
warn "logs now live in RAM only — harder to debug past-boot issues (revert: remove that drop-in)"

# =============================================================================
# Identity randomization at boot — random hostname (MAC handled by NM)
# =============================================================================
info "boot-time hostname randomization service"
cat > /usr/local/bin/randomize-identity <<'EOF'
#!/usr/bin/env bash
# Set a neutral random hostname each boot so it can't correlate you across
# networks. MAC is already randomized per-connection by NetworkManager.
set -euo pipefail
name="$(tr -dc 'a-z' </dev/urandom | head -c6)"
hostnamectl set-hostname "$name" 2>/dev/null || hostname "$name"
# keep /etc/hosts in sync so sudo doesn't stall resolving the hostname
sed -i "s/^127.0.1.1.*/127.0.1.1\t$name/" /etc/hosts 2>/dev/null || true
EOF
chmod +x /usr/local/bin/randomize-identity
cat > /etc/systemd/system/randomize-identity.service <<'EOF'
[Unit]
Description=Randomize hostname at boot (privacy)
Before=network-pre.target NetworkManager.service
Wants=network-pre.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/randomize-identity
[Install]
WantedBy=multi-user.target
EOF
systemctl enable randomize-identity.service 2>/dev/null || warn "could not enable randomize-identity"
ok "hostname will randomize each boot (disable: systemctl disable randomize-identity)"

# =============================================================================
# WireGuard kill-switch helper — fail closed if the tunnel drops
# =============================================================================
cat > /usr/local/bin/vpn-killswitch <<'EOF'
#!/usr/bin/env bash
# Fail-closed kill-switch. When ON, only the WireGuard tunnel + the VPN
# endpoint are allowed out; if the tunnel drops, traffic is blocked instead
# of leaking to your real IP.
#   sudo vpn-killswitch on <endpoint_ip> <udp_port> [wg_iface]
#   sudo vpn-killswitch off
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
case "${1:-}" in
  on)
    ep="${2:?endpoint IP}"; port="${3:?udp port}"; wgif="${4:-wg0}"
    ufw --force reset >/dev/null
    ufw default deny incoming; ufw default deny outgoing
    ufw allow out on lo; ufw allow in on lo
    ufw allow out to "$ep" port "$port" proto udp
    ufw allow out on "$wgif"
    ufw --force enable
    echo "kill-switch ON — only $wgif + $ep:$port/udp allowed out";;
  off)
    ufw --force reset >/dev/null
    ufw default deny incoming; ufw default allow outgoing
    ufw allow out on lo; ufw allow in on lo
    ufw --force enable
    echo "kill-switch OFF — restored default (deny in / allow out)";;
  *) echo "usage: vpn-killswitch on <endpoint_ip> <udp_port> [wg_iface] | off"; exit 1;;
esac
EOF
chmod +x /usr/local/bin/vpn-killswitch
ok "installed helper: vpn-killswitch (also see the wg-quick PostUp snippet in docs)"

cat <<EOF
${_c_blue}[*]${_c_reset} tor service is installed but OFF. Start when needed:
      sudo systemctl start tor    then    proxychains4 <cmd> / torsocks <cmd>
${_c_yellow}[!]${_c_reset} kalitorify routes ALL traffic via Tor but is LEAK-PRONE. For real
    anonymity use Whonix VMs (your vmlab) or Tails. See docs/ANONYMITY.md.
${_c_blue}[*]${_c_reset} Test for leaks after connecting a VPN/Tor:
      DNS  -> https://dnsleaktest.com     IP -> https://check.torproject.org
EOF

ok "anonymity module complete"
