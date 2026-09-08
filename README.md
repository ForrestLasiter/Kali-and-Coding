# Kali Linux for the Lenovo ThinkPad T490s

A repeatable, version-controlled setup for a fresh Kali install on a ThinkPad
T490s (8th-gen Whiskey Lake i7, 16 GB RAM, 256 GB NVMe). You install stock Kali
with **LUKS full-disk encryption**, then run one **idempotent provisioning
script** that lays down all the extra software, hardening, ThinkPad tuning, and
dotfiles.

> **Approach:** official installer + post-install script (chosen deliberately
> over a baked custom ISO — this is far easier to maintain, re-run, and tweak).

## Hardware reality check (good news)

The T490s is one of the best-supported laptops for Linux. Nothing here needs
out-of-tree drivers:

| Component | Part | Linux status |
|---|---|---|
| CPU | i7-8565U / 8665U (Whiskey Lake) | native, add `intel-microcode` |
| GPU | Intel UHD 620 | native (i915), GuC/HuC enabled in module 60 |
| Wi-Fi | Intel 9560 (or 9260) | native (`iwlwifi`) |
| Ethernet dock | Intel I219 | native |
| Fingerprint | Synaptics/Validity | works via `libfprint` (module 60) — a few units vary |
| Firmware/BIOS | — | updatable in-OS via `fwupd`/LVFS |

So the work is **software + power tuning + hardening**, not driver hunting.

---

## Part 1 — Make the installer USB

On this Windows box (or any machine):

1. Download the **Kali Installer** (not Live) ISO + its SHA256:
   <https://www.kali.org/get-kali/#kali-installer-images>
2. **Verify the download** before flashing:
   ```bash
   sha256sum kali-linux-*-installer-amd64.iso
   ```
   Compare against the value on the Kali site (and ideally the signed
   `SHA256SUMS` + `SHA256SUMS.gpg`).
3. Flash to an 8 GB+ USB with **Rufus** (Windows) in **DD mode**, or:
   ```bash
   # Linux/WSL — DOUBLE-CHECK the device node first!
   sudo dd if=kali-linux-*-installer-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

## Part 2 — T490s BIOS/UEFI settings

Boot into BIOS (tap **Enter** at the ThinkPad logo → **F1**):

- **Security → Secure Boot → Disabled** (simplest for Kali; you can re-enable
  with signed shim later if you care).
- **Config → Thunderbolt(TM) 3 → set BIOS Assist / disable Thunderbolt boot** to
  reduce DMA attack surface (optional).
- **Security → Memory Protection → Execution Prevention → Enabled**.
- **Security → Virtualization → Intel (R) Virtualization Technology → Enabled**
  (and **VT-d → Enabled**) — required for the KVM/QEMU VM lab (module 15).
- **Security → I/O Port Access** — disable radios/ports you never use (optional).
- **Startup → UEFI/Legacy Boot → UEFI Only**.
- Set a **supervisor password** and a **power-on/NVMe (drive) password** for
  defense-in-depth alongside LUKS (optional but recommended).
- Save (**F10**), boot from the USB (**F12** boot menu).

## Part 3 — Install Kali with LUKS full-disk encryption

Run the **Graphical install**. Key screens:

1. Hostname / user: create your normal non-root user (e.g. `forrest`).
2. **Partitioning → Guided – use entire disk and set up encrypted LVM.**
   - Select the 256 GB NVMe.
   - "All files in one partition" is fine for a laptop.
   - Set a **strong LUKS passphrase** (this is your at-rest protection —
     make it long; you'll type it at every boot).
   - Let it erase/overwrite the disk if you have time (slower but cleaner).
3. Software selection: keep the default desktop + **`kali-linux-default`**
   (the provision script will add/confirm this anyway).
4. GRUB → install to the NVMe (`/dev/nvme0n1`).
5. Reboot, remove USB, unlock with your LUKS passphrase, log in.

> After first login, note your disk device (usually `/dev/nvme0n1`, LUKS
> partition `/dev/nvme0n1p3`) — referenced in the hardening notes.

## Part 4 — Run the provisioning script

Get this folder onto the laptop (USB, `git clone`, or `scp`), then:

```bash
cd kali-t490s
chmod +x provision.sh
sudo ./provision.sh            # runs every module in order
```

That's it. Reboot when it finishes (for docker group, kernel/i915, firmware).

### Running pieces individually

```bash
sudo ./provision.sh list          # show modules
sudo ./provision.sh 10 30         # only dev + osint
sudo ./provision.sh 60            # only ThinkPad hardware tuning
```

It's **idempotent** — re-run any time to pick up new tools or after edits.

---

## What gets installed

| Module | Contents |
|---|---|
| `00-base` | full-upgrade, core CLI, `kali-linux-default` + top-10 metapackages |
| `10-dev` | zsh + oh-my-zsh + starship, tmux, bat/eza/ripgrep/fd/fzf/delta, **VSCodium** (telemetry-free) + **~25 Open VSX extensions** (open-remote-ssh, Ruff, basedpyright, ESLint, Prettier, Astro, REST Client, OpenAPI, Docker, Go, rust-analyzer, GitLens, ErrorLens…), **Docker**, **Go 1.23**, **Node via nvm**, **Rust/rustup**, **gh CLI**, pipx |
| `12-dev-extras` | **uv** (Python) + ruff/mypy/black, **pnpm/yarn** (corepack) + **Bun**, **lazygit**/tig/git-lfs, DB clients (**pgcli**/DBeaver/psql/sqlite3/redis), **httpie**/**Bruno**, **zoxide**/**atuin**/tldr, just/watchexec/hyperfine/tokei, lazydocker/dive, **age/sops** |
| `15-vmlab` | **KVM/QEMU + virt-manager** + libvirt, OVMF/swtpm (Win11 guests), user added to libvirt/kvm groups |
| `20-browsers-comms` | Firefox ESR (+ hardening `user.js`), **Brave**, **Signal**, **Element**, Thunderbird, **WireGuard**/OpenVPN, ProtonVPN |
| `25-anonymity` | **Tor** + torsocks + proxychains4, **Tor Browser**, mat2 (metadata scrub), nyx — pairs with your homevpn/Whonix |
| `30-osint` | amass, theHarvester, recon-ng, spiderfoot, maltego, sherlock, **ProjectDiscovery suite** (subfinder/httpx/nuclei/dnsx/naabu/katana), holehe — pairs with your **ReconLens** stack |
| `35-offensive` | **seclists**, ffuf/feroxbuster/gobuster, sqlmap, nikto, wpscan, **netexec**, impacket, **BloodHound**, responder, kerbrute, hashcat/john/hydra, **ghidra**, radare2, gdb+GEF, pwntools, metasploit, searchsploit |
| `40-productivity` | **Obsidian**, **KeePassXC**, Bitwarden, VLC/mpv, Flameshot, LibreOffice, GIMP, OBS, coding fonts |
| `50-hardening` | ufw default-deny, ssh off + hardened, **MAC randomization**, sysctl hardening, fail2ban, cautious auto-updates |
| `52-hwtoken` | **YubiKey**/FIDO2 tooling (ykman, pcscd, pam-u2f/yubico) — PAM left for you to wire (lockout-safe) |
| `60-thinkpad` | intel-microcode, **fwupd**, **TLP** + charge thresholds, thermald, **fingerprint**, powertop, i915 GuC/HuC |
| `70-resilience` | **Timeshift** snapshots + **restic** encrypted backups, `snap-before-upgrade` + `backup-home` helper scripts |
| `80-extras` | **Nerd Font** (prompt glyphs), **Flatpak/Flathub**, **Syncthing** (cloud-free vault/file sync across your homelab) |
| `90-dotfiles` | `.zshrc`, `.tmux.conf`, `.gitconfig`, starship, nvim config, telemetry-off VSCodium `settings.json` (backs up existing files) |

### Adding your own packages
Edit `packages/extra-apt.txt`, then:
```bash
sudo apt install -y $(grep -vE '^\s*(#|$)' packages/extra-apt.txt)
```

---

## Post-provision manual steps (2 minutes)

1. **Reboot**, then update firmware:
   ```bash
   sudo fwupdmgr refresh && sudo fwupdmgr get-updates && sudo fwupdmgr update
   ```
2. **Enroll fingerprint** (optional): `fprintd-enroll` then `sudo pam-auth-update`.
3. **Firefox hardening**: copy `dotfiles/firefox-user.js` to your profile's
   `user.js` (path shown at `about:profiles`).
4. **LUKS backup key** (so one forgotten passphrase ≠ dead disk):
   ```bash
   sudo cryptsetup luksAddKey /dev/nvme0n1p3
   sudo cryptsetup luksHeaderBackup /dev/nvme0n1p3 --header-backup-file luks-header.img
   ```
   Store that header image somewhere safe & offline.
5. **Confirm the shell**: log out/in (or `exec zsh`) to load the new prompt.

## Maintenance

Kali is a rolling distro — update deliberately, not automatically. Take a
Timeshift snapshot first (module 70 gives you a one-shot helper for exactly this):
```bash
sudo snap-before-upgrade      # snapshot, then full-upgrade (roll back if it breaks)
nuclei -update-templates
```

## Notes / caveats

- Third-party `.deb` versions (Obsidian, Bitwarden) are pinned in the modules;
  bump the version variables when they go stale — a failed download only warns,
  never aborts the run.
- Auto-**install** of updates is intentionally **off** (module 50) because
  unattended full-upgrades can break tooling on a rolling distro.
- Don't install both TLP and `power-profiles-daemon`; module 60 removes the
  latter to avoid the conflict.
