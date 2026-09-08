#!/usr/bin/env bash
# 54-keys.sh — SSH + GPG key bootstrap with hardened defaults.
# Generates an ed25519 SSH key if you don't have one, lays down a hardened
# client config, and sets up agent handling. GPG is configured but NOT
# auto-generated (key creation needs your identity input — do it yourself).

apt_install keychain

# --- hardened SSH client config ---------------------------------------------
SSH_DIR="$RUN_HOME/.ssh"
install -d -m 700 -o "$RUN_USER" -g "$RUN_USER" "$SSH_DIR"
if [[ ! -f "$SSH_DIR/config" ]]; then
  cat > "$SSH_DIR/config" <<'EOF'
# Hardened SSH client defaults
Host *
    HashKnownHosts yes
    ForwardAgent no
    ForwardX11 no
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentitiesOnly yes
EOF
  chmod 600 "$SSH_DIR/config"; chown "$RUN_USER:$RUN_USER" "$SSH_DIR/config"
  ok "wrote hardened ~/.ssh/config"
fi

# --- ed25519 key (only if none exists) --------------------------------------
if ! ls "$SSH_DIR"/id_* >/dev/null 2>&1; then
  info "generating ed25519 SSH key for $RUN_USER"
  as_user 'ssh-keygen -t ed25519 -a 100 -N "" -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519"' \
    || warn "ssh-keygen failed"
  note "SSH key created WITHOUT a passphrase. Add one: ssh-keygen -p -f ~/.ssh/id_ed25519"
else
  ok "existing SSH key found — leaving it alone"
fi

# --- GPG hardening (agent + conf); key creation left to you -----------------
GNUPG="$RUN_HOME/.gnupg"
install -d -m 700 -o "$RUN_USER" -g "$RUN_USER" "$GNUPG"
cat > "$GNUPG/gpg.conf" <<'EOF'
personal-cipher-preferences AES256 AES192 AES
personal-digest-preferences SHA512 SHA384 SHA256
cert-digest-algo SHA512
default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
keyid-format 0xlong
with-fingerprint
require-cross-certification
no-emit-version
EOF
chown -R "$RUN_USER:$RUN_USER" "$GNUPG"
chmod 600 "$GNUPG/gpg.conf"

cat <<EOF
${_c_blue}[*]${_c_reset} Public key to add to GitHub/servers:  cat ~/.ssh/id_ed25519.pub
${_c_blue}[*]${_c_reset} Agent: keychain is set up in your .zshrc (loads the key once per boot).
${_c_blue}[*]${_c_reset} GPG: create a key yourself when ready — 'gpg --full-generate-key'
    (ed25519). gpg.conf is already hardened.
EOF

ok "keys module complete"
