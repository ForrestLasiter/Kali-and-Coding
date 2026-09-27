# Practice Range

A one-command, deliberately-vulnerable lab that runs entirely on **your own
laptop**, on an **isolated network with no route to your LAN or the internet**.
It gives you a legal place to point every tool the kit installs.

Installed by module `16-range`, which builds on `15-vmlab` (KVM/libvirt) and the
Docker install from `10-dev`.

```
range up juice-shop      # start a target
range down               # stop everything
range reset dvwa         # wipe a target back to clean
range status             # what's running + how to reach it
range list               # available targets
```

## Why it's safe

Vulnerable-by-design targets must never be reachable from an untrusted network.
The range enforces that two ways:

- **Docker targets** (juice-shop, DVWA) publish only to `127.0.0.1` — nothing on
  your Wi-Fi/LAN can reach them — and run on an `--internal` Docker network, so
  the container itself has **no outbound route** (it can't phone home or be
  pivoted out to the internet).
- **VM targets** (metasploitable2, an AD lab) attach to the isolated libvirt
  network `range` (`192.168.66.0/24`). It has **no `<forward>`**, so guests can
  talk to each other and to the host, but have no NAT to the LAN or internet.

The one exception is your attacker box (Kali itself): it reaches the targets
because it *is* the host, or because you attach a Kali VM to the same `range`
network. That's the whole point — a closed shooting range.

## Targets

| Target            | Backend | Reach                          | Notes |
|-------------------|---------|--------------------------------|-------|
| `juice-shop`      | Docker  | `http://127.0.0.1:3000`        | OWASP Juice Shop — modern web app |
| `dvwa`            | Docker  | `http://127.0.0.1:8080`        | Damn Vulnerable Web App (login `admin`/`password`) |
| `metasploitable2` | KVM VM  | `192.168.66.x` (see `status`)  | Import first (below) |
| `ad-lab`          | guided  | `range` network                | Lightweight Active Directory — see below |

Docker targets start in seconds. Point your tools at the loopback URL:

```
nikto -h http://127.0.0.1:3000
sqlmap -u 'http://127.0.0.1:8080/vulnerabilities/sqli/?id=1&Submit=Submit' --cookie=...
```

## Importing a VM target (metasploitable2)

Metasploitable can't be redistributed, so you download it once and import it.
The import is signature-agnostic but the network is isolated, so a compromised
guest still can't reach out.

1. Download **Metasploitable 2** from a source you trust (e.g. SourceForge) and
   unzip it — you'll get a `.vmdk` disk.
2. Import it (converts to qcow2, defines the VM on the `range` network, and
   snapshots a clean baseline):
   ```
   range import metasploitable2 ~/Downloads/Metasploitable2-Linux/
   ```
3. Run it and find its IP:
   ```
   range up metasploitable2
   range status          # shows the DHCP lease on 192.168.66.x
   ```
4. Break it, then put it back:
   ```
   range reset metasploitable2    # reverts to the 'range-clean' snapshot
   ```

## AD lab (guided)

A realistic Active Directory lab needs at least one Windows domain controller,
which is too heavy to spin up as a single container and can't be auto-downloaded.
The isolated `range` network is ready for it — just attach every AD VM to it so
the lab stays sealed off:

- **Lightweight:** a single Windows Server evaluation VM promoted to a domain
  controller. Enough to practice enumeration, Kerberoasting, and BloodHound
  collection against a real DC.
- **Full lab:** [GOAD](https://github.com/Orange-Cyberdefense/GOAD) (Game of
  Active Directory) or vulnAD. GOAD is multi-VM and RAM-hungry — on 16 GB run the
  "light" variant and start VMs as you need them.

In each case, create the VMs in `virt-manager` and set their network to the
existing isolated network **`range`** (not `default`, which has NAT to the
internet). Your Kali host reaches them over `192.168.66.0/24`.

## Under the hood

- Docker network: `range` (internal, no egress); containers named `range-<target>`.
- libvirt network: `range` (isolated, `192.168.66.0/24`, DHCP `.100–.199`);
  domains named `range-<target>`; clean state kept in a `range-clean` snapshot.
- CLI: `/usr/local/bin/range`. It uses `sudo` for docker/virsh only if your user
  isn't in the `docker`/`libvirt` groups yet (re-login after first provision).

Tear the whole thing down with `range down`; the networks persist so the next
`range up` is instant.
