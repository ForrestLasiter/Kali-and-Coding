#!/usr/bin/env bash
# 38-pivoting.sh — tunneling / pivoting / C2 for AUTHORIZED engagements only.
# These are dual-use tools. Use them solely on systems you are explicitly
# permitted to test; unauthorized use is illegal.

info "pivoting / tunneling tools"
apt_install proxychains4 socat

# chisel — fast TCP/UDP tunnel over HTTP (apt in Kali, else go install)
apt_install chisel || \
  ( command -v go >/dev/null && \
    as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/jpillora/chisel@latest' ) \
  || warn "chisel not installed"

# ligolo-ng — modern tunneling (proxy + agent) via go install
if command -v go >/dev/null; then
  info "ligolo-ng (proxy + agent)"
  as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/nicocha30/ligolo-ng/cmd/proxy@latest' || warn "ligolo proxy failed"
  as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/nicocha30/ligolo-ng/cmd/agent@latest' || warn "ligolo agent failed"
fi

# sliver — C2 framework (apt in Kali, else official installer)
if ! command -v sliver-server >/dev/null 2>&1; then
  apt_install sliver || {
    info "installing sliver via official script"
    curl -fsSL https://sliver.sh/install | bash || warn "sliver install failed"
  }
fi

cat <<EOF
${_c_yellow}[!]${_c_reset} AUTHORIZED USE ONLY. chisel/ligolo-ng/sliver are for engagements you
    have written permission to perform. Tools land in ~/go/bin (ligolo/chisel)
    and /usr/local (sliver).
EOF

ok "pivoting module complete"
