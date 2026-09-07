#!/usr/bin/env bash
# 30-osint.sh — OSINT / recon tooling beyond Kali defaults.
# Complements your ReconLens stack (self-hosted attack-surface monitor).

# --- packaged in Kali repos --------------------------------------------------
info "OSINT packages from Kali repos"
apt_install \
  amass \
  theharvester \
  recon-ng \
  dnsrecon dnsenum fierce \
  whatweb wafw00f \
  maltego \
  spiderfoot \
  photon \
  sherlock \
  exiftool \
  masscan

# --- ProjectDiscovery suite via `go install` (latest) -----------------------
# Kali packages some of these but go install keeps them current. Installs to
# the user's ~/go/bin so they're owned by the user, not root.
if command -v go >/dev/null 2>&1; then
  info "ProjectDiscovery tools via go install (as $RUN_USER)"
  pd_tools=(
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
  )
  for t in "${pd_tools[@]}"; do
    as_user "export PATH=\$PATH:/usr/local/go/bin GOPATH=\$HOME/go; go install $t" \
      || warn "go install failed: $t"
  done
  ok "PD tools in $RUN_HOME/go/bin (added to PATH in dotfiles)"
  # nuclei templates
  as_user 'export PATH=$PATH:$HOME/go/bin; command -v nuclei >/dev/null && nuclei -update-templates >/dev/null 2>&1 || true'
else
  warn "Go not found — skipping ProjectDiscovery tools (run module 10 first)"
fi

# --- pipx-installed python OSINT tools --------------------------------------
info "python OSINT tools via pipx (as $RUN_USER)"
pipx_tools=(holehe socialscan)
for t in "${pipx_tools[@]}"; do
  as_user "pipx install $t" || warn "pipx install failed: $t"
done

# --- ReconLens hook ----------------------------------------------------------
cat <<EOF
${_c_blue}[*]${_c_reset} ReconLens: this laptop is Docker-ready. To bring up your
    self-hosted OSINT/attack-surface monitor, clone your reconlens repo and run
    its compose stack. (Scope-gating rules from that project still apply.)
EOF

ok "osint module complete"
