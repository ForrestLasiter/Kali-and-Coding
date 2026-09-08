#!/usr/bin/env bash
# 52-hwtoken.sh — YubiKey / FIDO2 hardware-token support.
# Installs tooling and the PAM modules but does NOT edit PAM automatically —
# a wrong PAM edit can lock you out of your own machine. Enrollment steps are
# printed for you to run deliberately.

info "YubiKey / smartcard tooling"
apt_install \
  yubikey-manager \
  yubikey-personalization \
  yubioath-desktop \
  pcscd libpam-u2f libpam-yubico

# smartcard daemon (needed for OATH/PIV/OpenPGP on the key)
systemctl enable --now pcscd 2>/dev/null || warn "could not enable pcscd"

cat <<EOF
${_c_yellow}[!]${_c_reset} PAM is NOT modified automatically (lockout risk). To enable a YubiKey
    as a 2nd factor for login/sudo, do this AFTER confirming the key works:

    1) Register the key (do it for a BACKUP key too):
         mkdir -p ~/.config/Yubico
         pamu2fcfg > ~/.config/Yubico/u2f_keys
         pamu2fcfg -n >> ~/.config/Yubico/u2f_keys    # tap backup key

    2) Add this line ABOVE the existing auth lines in the PAM file you want,
       e.g. /etc/pam.d/sudo (test in ONE file first, keep a root shell open):
         auth  required  pam_u2f.so   cue

    3) Test in a SEPARATE terminal before closing your root shell.

    Check the key is seen:  ykman info    /    ykman list
EOF

ok "hwtoken module complete"
