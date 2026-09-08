#!/usr/bin/env bash
# 36-webapp.sh — web application testing proxies & scanners.
# Burp Suite (community) already ships with Kali; this adds the open stack.

info "web app proxies + scanners"
apt_install \
  zaproxy \
  mitmproxy \
  wapiti \
  commix \
  wpscan \
  nikto

cat <<EOF
${_c_blue}[*]${_c_reset} Proxies: mitmproxy/mitmweb (CLI), OWASP ZAP (zaproxy), Burp Suite
    (ships with Kali). Caido is not packaged — grab the .deb from caido.io
    if you want it.
${_c_blue}[*]${_c_reset} mitmproxy CA cert: run 'mitmproxy' once, then install ~/.mitmproxy/
    mitmproxy-ca-cert.pem into the browser/system trust to intercept TLS.
EOF

ok "webapp module complete"
