# Kali Linux + Coding — laptop provisioning kit

A repeatable, version-controlled setup for a fresh Kali install on **any UEFI
laptop**. You install stock Kali with **LUKS full-disk encryption**, then run one
**idempotent provisioning script** that lays down all the extra software (dev
tooling, OSINT/offensive, anonymity), hardening, hardware tuning, and dotfiles.

> **Approach:** official installer + post-install script (chosen deliberately
> over a baked custom ISO — far easier to maintain, re-run, and tweak).
>
> **Hardware-agnostic:** module `60-hardware` auto-detects your CPU (Intel/AMD
> microcode), GPU (Intel/AMD firmware; NVIDIA flagged), and laptop vendor
> (battery charge thresholds applied only where the firmware supports them, e.g.
> ThinkPads). No per-model editing — it adapts to the machine it runs on.

📊 **Visual walkthrough of the scripting process:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
(diagrams render on GitHub) · 🔒 **Anonymity/OPSEC guide:** [docs/ANONYMITY.md](docs/ANONYMITY.md)

## Hardware support

Modern laptops are well supported by Kali's kernel; the kit's job is **software
+ power tuning + hardening**, not driver hunting. What `60-hardware` does per
component:

| Component | Handling |
|---|---|
| CPU | `intel-microcode` **or** `amd64-microcode` by detected vendor; thermald on Intel |
| GPU | Intel → i915 GuC/HuC + VA driver · AMD → `firmware-amd-graphics` · NVIDIA → flagged (opt in with `INSTALL_GPU_DRIVER=nvidia`) |
| Wi-Fi | native (`iwlwifi`/`ath`/…); external monitor-mode adapter driver in module 37 |
| Fingerprint | `libfprint`/`fprintd` (works across most vendors) |
| Battery | charge thresholds via TLP **only where the firmware exposes them** |
| Firmware/BIOS | `fwupd`/LVFS, in-OS |

> **Reference build:** originally developed and VM-tested against a Lenovo
> ThinkPad T490s (8th-gen Intel, Intel UHD 620, Intel 9560 Wi-Fi). It runs
> unmodified on other laptops thanks to the detection above.

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

## Part 2 — BIOS/UEFI settings

Enter your firmware setup (usually **F1/F2/F10/Del** at the vendor logo; the key
varies by maker). Names differ per vendor, but set the equivalents of:

- **Secure Boot → Disabled** (simplest for Kali; re-enable with a signed shim
  later if you want it).
- **CPU virtualization → Enabled** — Intel **VT-x**/**VT-d** or AMD **SVM/IOMMU**.
  Required for the KVM/QEMU VM lab (module 15).
- **Boot mode → UEFI only** (disable legacy/CSM).
- **DMA/Thunderbolt protection → on** (reduce DMA attack surface) — optional.
- Set a **supervisor/BIOS password** and, if offered, a **drive (HDD/NVMe)
  password** for defense-in-depth alongside LUKS — optional but recommended.
- Save and boot from the USB (a one-time boot menu is usually **F12/F9/Esc**).

## Part 3 — Install Kali with LUKS full-disk encryption

Run the **Graphical install**. Key screens:

1. Hostname / user: create your normal non-root user (e.g. `anon`).
2. **Partitioning → Guided – use entire disk and set up encrypted LVM.**
   - Select your internal disk (NVMe or SATA SSD).
   - "All files in one partition" is fine for a laptop.
   - Set a **strong LUKS passphrase** (this is your at-rest protection —
     make it long; you'll type it at every boot).
   - Let it erase/overwrite the disk if you have time (slower but cleaner).
3. Software selection: keep the default desktop + **`kali-linux-default`**
   (the provision script will add/confirm this anyway).
4. GRUB → install to your internal disk (e.g. `/dev/nvme0n1` or `/dev/sda`).
5. Reboot, remove USB, unlock with your LUKS passphrase, log in.

> After first login you can find your LUKS partition with
> `lsblk -f | grep crypto_LUKS` — the provisioner detects it automatically for
> the backup-key hint.

## Part 4 — Run the provisioning script

Get this folder onto the laptop (USB, `git clone`, or `scp`), then:

```bash
cd Kali-and-Coding
chmod +x provision.sh
sudo ./provision.sh            # runs every module in order
```

That's it. Reboot when it finishes (for docker group, kernel/i915, firmware).

### Running pieces individually

```bash
./provision.sh list               # show modules (no root needed)
./provision.sh --dry-run          # print the install plan, change nothing
./provision.sh doctor             # preflight checks (OS/arch/disk/network)
sudo ./provision.sh 10 30         # only dev + osint
sudo ./provision.sh 60            # only hardware tuning (microcode/GPU/TLP)
```

It's **idempotent** — re-run any time to pick up new tools or after edits.
Every real run is **logged** to `/var/log/<KIT_NAME>-<timestamp>.log`, and ends
with a **summary of any warnings** (e.g. packages that failed to install).
`--dry-run` and `doctor`/`list` need no root; the full run runs a preflight
first and aborts early if there's no network.

---

## What gets installed

| Module | Contents |
|---|---|
| `00-base` | full-upgrade, core CLI, `kali-linux-default` + top-10 metapackages |
| `10-dev` | zsh + oh-my-zsh + starship, tmux, bat/eza/ripgrep/fd/fzf/delta, **VSCodium** (telemetry-free) + **~25 Open VSX extensions** (open-remote-ssh, Ruff, basedpyright, ESLint, Prettier, Astro, REST Client, OpenAPI, Docker, Go, rust-analyzer, GitLens, ErrorLens…), **Docker**, **Go 1.23**, **Node via nvm**, **Rust/rustup**, **gh CLI**, pipx |
| `12-dev-extras` | **uv** (Python) + ruff/mypy/black, **pnpm/yarn** (corepack) + **Bun**, **lazygit**/tig/git-lfs, DB clients (**pgcli**/DBeaver/psql/sqlite3/redis), **httpie**/**Bruno**, **zoxide**/**atuin**/tldr, just/watchexec/hyperfine/tokei, lazydocker/dive, **age/sops** |
| `15-vmlab` | **KVM/QEMU + virt-manager** + libvirt, OVMF/swtpm (Win11 guests), user added to libvirt/kvm groups |
| `20-browsers-comms` | Firefox ESR (+ hardening `user.js`), **Brave**, **Signal**, **Element**, Thunderbird, **WireGuard**/OpenVPN, ProtonVPN |
| `25-anonymity` | **Tor**/torsocks/proxychains4, **Tor Browser** + **Mullvad Browser**, **dnscrypt-proxy** (encrypted DNS) + IPv6 leak-off, mat2, **kalitorify**, anti-forensics (BleachBit/secure-delete + `wipe-traces`), journald-in-RAM, boot hostname randomization, **`vpn-killswitch`** helper — see [docs/ANONYMITY.md](docs/ANONYMITY.md) |
| `30-osint` | amass, theHarvester, recon-ng, spiderfoot, maltego, sherlock, **ProjectDiscovery suite** (subfinder/httpx/nuclei/dnsx/naabu/katana), holehe — pairs with a self-hosted recon stack |
| `35-offensive` | **seclists**, ffuf/feroxbuster/gobuster, sqlmap, nikto, wpscan, **netexec**, impacket, **BloodHound**, responder, kerbrute, hashcat/john/hydra, **ghidra**, radare2, gdb+GEF, pwntools, metasploit, searchsploit |
| `36-webapp` | **OWASP ZAP**, **mitmproxy**, wapiti, commix (Burp ships with Kali; Caido optional) |
| `37-wireless` | **realtek-rtl88xxau DKMS** (external-adapter injection) + aircrack-ng, kismet, wifite, bettercap, hcxtools, reaver, airgeddon |
| `38-pivoting` | **chisel**, **ligolo-ng**, **sliver**, socat — *authorized engagements only* |
| `40-productivity` | **Obsidian**, **KeePassXC**, Bitwarden, VLC/mpv, Flameshot, LibreOffice, GIMP, OBS, coding fonts |
| `45-engagements` | **pandoc + LaTeX** (Markdown→PDF reports), CherryTree, `~/engagements` scaffold + **`new-engagement`** helper |
| `50-hardening` | ufw default-deny, ssh off + hardened, **MAC randomization**, sysctl hardening, fail2ban, cautious auto-updates, **NM-owns-wifi fix** (neutralizes a leftover ifupdown wlan stanza that breaks Wi-Fi after the desktop installs) |
| `52-hwtoken` | **YubiKey**/FIDO2 tooling (ykman, pcscd, pam-u2f/yubico) — PAM left for you to wire (lockout-safe) |
| `54-keys` | **ed25519 SSH key** bootstrap + hardened `~/.ssh/config`, keychain agent, GPG hardening (key creation left to you) |
| `60-hardware` | **auto-detected**: Intel/AMD microcode, GPU firmware/driver (Intel i915 · AMD · NVIDIA-flagged), **fwupd**, **TLP** + charge thresholds where supported, thermald, **fingerprint**, powertop, bluetooth |
| `70-resilience` | **Timeshift** snapshots + **restic** encrypted backups, `snap-before-upgrade` + `backup-home` helper scripts |
| `80-extras` | **Nerd Font** (prompt glyphs), **Flatpak/Flathub**, **Syncthing** (cloud-free vault/file sync across your own machines) |
| `82-qol` | CLI: duf/dust/procs/sd/glow/fastfetch, **yazi**+nnn, navi+thefuck, **kitty**. Desktop (XFCE): **rofi** launcher, picom, **udiskie** automount, **gammastep** night light, Papirus+Arc themes, zathura/peek/xarchiver/gpick. Also **disables brltty** (the braille service whose xbrlapi hook hangs graphical login ~135s) |
| `90-dotfiles` | `.zshrc`, `.tmux.conf`, `.gitconfig`, starship, nvim config, telemetry-off VSCodium `settings.json` (backs up existing files) |
| `95-firstboot` | installs **`first-boot-checklist`** — interactive walk-through of the post-install manual steps |

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
4. **LUKS backup key** (so one forgotten passphrase ≠ dead disk) — find your
   encrypted partition first, then use it in place of `$LUKS` below:
   ```bash
   LUKS=$(lsblk -rno NAME,FSTYPE | awk '$2=="crypto_LUKS"{print "/dev/"$1}')
   sudo cryptsetup luksAddKey "$LUKS"
   sudo cryptsetup luksHeaderBackup "$LUKS" --header-backup-file luks-header.img
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
- Do not install both TLP and `power-profiles-daemon`; module `60-hardware` removes the
  latter to avoid the conflict.
