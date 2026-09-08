# Anonymity & OPSEC guide — Kali T490s

Read this before trusting anything in module `25-anonymity`. Tools reduce
leaks; they do **not** make an identified machine anonymous.

## The core truth: compartmentalize, don't retrofit

This laptop has a **strong, persistent identity**: your real name/email in
`~/.gitconfig`, your GitHub auth, VSCodium + extensions, Syncthing paired to
your homelab, browser logins, SSH keys. Routing that same OS through Tor or a
VPN does not anonymize it — the *content and accounts* still identify you.

**Anonymous activity belongs in a separate, disposable context:**

| Need | Use | Why |
|---|---|---|
| Strong, leak-proof anonymity | **Whonix** (Gateway + Workstation VMs) | The Gateway forces *all* Workstation traffic through Tor at the network layer — an app **cannot** leak your real IP even if it tries. |
| Amnesic, leaves no trace | **Tails** (live USB) | Runs from RAM, forgets everything on shutdown, all traffic via Tor. |
| De-fingerprinted browsing (not full anon) | **Mullvad Browser** + your VPN | Tor-Browser-grade fingerprint resistance without the Tor network's latency. |
| Convenience masking on the daily driver | dnscrypt / VPN / kalitorify | Reduces passive leaks. **Not** anonymity. |

Rule of thumb: if it *matters*, do it in Whonix or Tails — not in your Kali
daily driver.

## Whonix on this laptop (via the `15-vmlab` KVM setup)

1. Download the Whonix **KVM** build (Gateway + Workstation) from
   `whonix.org` and **verify its signature**.
2. **Verify the signature**, extract, then import with the scripted helper
   (installed by module `15-vmlab`):
   ```bash
   gpg --import <whonix-signing-key.asc>
   gpg --verify Whonix-*.libvirt.xz.asc Whonix-*.libvirt.xz   # must be GOOD
   tar -xvf Whonix-*.libvirt.xz
   sudo whonix-import <extracted-dir>     # defines networks + both VMs
   ```
3. Start the **Gateway** first, then the **Workstation**. The Workstation has
   no route to the internet except through the Gateway's Tor.
4. Do your anonymous work inside the Workstation. Snapshots let you roll back
   to a clean state after each session.

Whonix runs the same way on any KVM host (a Proxmox homelab, or this laptop) —
this is that model, running locally.

## Tails USB (highest assurance, amnesic)

1. Download the Tails USB image + verify (they provide a browser-extension /
   GPG verification flow).
2. Flash to a dedicated USB (`dd` or the Tails installer).
3. Boot the T490s from it (F12). Optionally set a persistent-storage volume
   (LUKS-encrypted) only if you truly need persistence — pure amnesic is safer.

## What the module changed on THIS box (and how to revert)

| Change | File / unit | Revert |
|---|---|---|
| Encrypted DNS on 127.0.0.1:53 | `dnscrypt-proxy.service`, `/etc/NetworkManager/conf.d/10-dnscrypt.conf` | `rm` the NM conf, `systemctl disable dnscrypt-proxy.service`, re-enable `dnscrypt-proxy.socket`, reload NM |
| IPv6 disabled | `/etc/sysctl.d/99-privacy-ipv6.conf` | delete the file, `sudo sysctl --system` |
| Logs in RAM only | `/etc/systemd/journald.conf.d/99-volatile.conf` | delete the drop-in, `systemctl restart systemd-journald` |
| Random hostname each boot | `randomize-identity.service` | `sudo systemctl disable randomize-identity.service` |
| MAC randomization | `/etc/NetworkManager/conf.d/00-macrandomize.conf` (module 50) | delete the file, reload NM |

## Helpers installed

- **`wipe-traces`** (run as your user) — clears caches, tmp, trash, recent
  docs, thumbnails, and shell history via BleachBit + manual clears.
- **`vpn-killswitch on <endpoint_ip> <udp_port> [wg_iface]` / `off`** —
  fail-closed firewall so a dropped WireGuard tunnel blocks traffic instead of
  leaking your real IP.
- **`secure-delete`** suite — `srm <file>` (secure file wipe), `sfill` (wipe
  free space), `sdmem` (wipe RAM), `sswap` (wipe swap).

### WireGuard kill-switch, the built-in way

Instead of the `vpn-killswitch` script you can bake it into the tunnel config
so it's automatic — add to the `[Interface]` section of your `wg0.conf`:

```ini
PostUp   = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown  = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
```

## Leak testing (do this after connecting)

- **IP / Tor**: <https://check.torproject.org> and <https://ipleak.net>
- **DNS**: <https://dnsleaktest.com> (extended test) — confirm only your
  resolver/VPN shows, not your ISP.
- **WebRTC**: `ipleak.net` shows WebRTC-exposed IPs — Mullvad/Tor Browser and
  the Firefox `user.js` (media.peerconnection.enabled=false) block this.

## OPSEC habits the tools can't give you

- Don't log into identified accounts (Google, GitHub) in an "anonymous"
  session — that instantly deanonymizes it.
- Keep anonymous and identified work in **different browsers/VMs/users**, never
  the same profile.
- Beware timing/behavioral correlation and writing style (stylometry).
- A unique hardware set + browser = a fingerprint; that's why Tor/Mullvad
  Browser normalize it. Don't install extra fonts/extensions in those browsers.
- Physical: full-disk encryption (you set LUKS) protects data at rest only
  while powered off. Lock/shutdown when away.
