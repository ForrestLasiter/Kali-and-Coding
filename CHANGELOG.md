# Changelog

All notable changes to this kit. Format loosely follows Keep a Changelog.

## [Unreleased]

### Added
- `--dry-run` (static install plan, changes nothing), `doctor` preflight
  (OS / arch / disk / network), timestamped run logging, and a post-run
  warning summary in `provision.sh`.
- `36-webapp` — OWASP ZAP, mitmproxy, wapiti, commix.
- `37-wireless` — realtek-rtl88xxau DKMS driver + aircrack-ng, kismet, wifite,
  bettercap, hcxtools, reaver, airgeddon.
- `38-pivoting` — chisel, ligolo-ng, sliver (authorized-use only).
- `45-engagements` — pandoc + LaTeX, an `~/engagements` scaffold, and a
  `new-engagement <name>` helper.
- `54-keys` — ed25519 SSH key bootstrap, hardened `~/.ssh/config`, keychain
  agent, GPG hardening.
- `95-firstboot` — interactive `first-boot-checklist` for post-install steps.
- Repo hygiene: MIT `LICENSE`, shellcheck CI, `CONTRIBUTING.md`, this file.

### Changed
- Genericized references to private projects/infrastructure for public sharing.
- Scrubbed personal identity from `dotfiles/gitconfig` (generic placeholders).

## [0.1.0]

### Added
- Initial kit: installer + LUKS-FDE walkthrough and a modular post-install
  `provision.sh` (base, dev, vmlab, browsers/comms, anonymity, osint,
  offensive, productivity, hardening, hwtoken, thinkpad, resilience, extras,
  qol, dotfiles), dotfiles, and docs (README, ARCHITECTURE, ANONYMITY).
