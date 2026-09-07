#!/usr/bin/env bash
# 25-anonymity.sh — Tor, proxying, and metadata hygiene.
# Complements your homevpn / Whonix workflow. Following the hardening
# philosophy, the tor SERVICE is installed but NOT auto-enabled — turn it on
# only when you need the local SOCKS proxy.

info "Tor, proxychains, torsocks, metadata scrubbing"
apt_install \
  tor \
  torsocks \
  proxychains4 \
  mat2 \
  torbrowser-launcher \
  nyx                    # tor status monitor

# proxychains: ensure dynamic_chain + the default tor SOCKS port are sane.
# We don't rewrite your config aggressively — just make sure 9050 is present.
PCONF="/etc/proxychains4.conf"
if [[ -f "$PCONF" ]]; then
  grep -q '^socks5\s\+127.0.0.1\s\+9050' "$PCONF" || \
    echo "socks5  127.0.0.1 9050" >> "$PCONF"
fi

cat <<EOF
${_c_blue}[*]${_c_reset} tor service is installed but OFF. When you want the local SOCKS proxy:
      sudo systemctl start tor        # (add 'enable' to persist)
    then: proxychains4 <cmd>   or   torsocks <cmd>   (SOCKS5 127.0.0.1:9050)
${_c_blue}[*]${_c_reset} Tor Browser: run 'torbrowser-launcher' as your user (first run downloads
    + signature-verifies the current Tor Browser to your home dir).
${_c_blue}[*]${_c_reset} Scrub metadata before sharing a file:  mat2 <file>
EOF

ok "anonymity module complete"
