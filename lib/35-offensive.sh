#!/usr/bin/env bash
# 35-offensive.sh — deeper offensive/CTF toolkit beyond the base metapackages.
# Only run on systems and targets you are authorized to test. Some packages
# are large (bloodhound pulls neo4j; ghidra is a big download).

info "Web / fuzzing / content discovery"
apt_install \
  seclists \
  ffuf feroxbuster gobuster dirb dirbuster wfuzz \
  sqlmap nikto wpscan whatweb \
  nuclei                       # also installed via go in module 30; apt is fine

info "AD / network / credential tooling"
apt_install \
  netexec impacket-scripts \
  responder \
  enum4linux-ng smbmap \
  evil-winrm \
  kerbrute \
  bloodhound                    # pulls neo4j; heavy but you asked for it

info "Password cracking"
apt_install hashcat john hydra medusa hashid hash-identifier

info "Reversing / exploitation / forensics"
apt_install \
  ghidra radare2 gdb \
  binwalk foremost \
  exploitdb \
  metasploit-framework \
  ltrace strace patchelf

# --- pwntools (exploit dev) via pipx, as the user ---------------------------
if command -v pipx >/dev/null 2>&1; then
  as_user 'pipx install pwntools' || warn "pwntools install failed"
fi

# --- GEF (GDB Enhanced Features) for the user's gdb -------------------------
if [[ ! -f "$RUN_HOME/.gdbinit-gef.py" ]]; then
  info "installing GEF (gdb enhancement) for $RUN_USER"
  as_user 'bash -c "$(curl -fsSL https://gef.blah.cat/sh)"' \
    || warn "GEF install failed (install manually if you want it)"
fi

cat <<EOF
${_c_blue}[*]${_c_reset} BloodHound needs neo4j running:  sudo neo4j console  (or 'neo4j start'),
    then log in at http://localhost:7474 (default neo4j/neo4j, change it).
${_c_blue}[*]${_c_reset} Wordlists live in /usr/share/seclists and /usr/share/wordlists
    (rockyou is at /usr/share/wordlists/rockyou.txt.gz — gunzip once).
EOF

ok "offensive module complete"
