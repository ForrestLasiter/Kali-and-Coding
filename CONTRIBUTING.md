# Contributing

Thanks for improving the kit. It targets **Kali Linux on any UEFI laptop
(amd64, arm64 best-effort)**; module 60-hardware auto-detects CPU/GPU/vendor.

## Ground rules

- **Keep it idempotent.** Re-running `provision.sh` must be safe. Use the
  `apt_install` / `add_apt_repo` / `install_deb` / `as_user` helpers from
  `lib/common.sh` rather than raw `apt-get` where you can — they already handle
  "already installed" and failures.
- **Fail soft.** A missing package or failed download should `warn` and
  continue, never abort the whole run.
- **User vs root.** Anything that belongs in a user's home (dotfiles, editor
  extensions, language toolchains) must go through `as_user` so it's owned by
  the user, not root.
- **No personal data.** No real names, emails, hostnames, keys, or private
  infrastructure names in committed files.

## Adding a module

1. Create `lib/NN-name.sh` (pick `NN` for run order — dependencies first).
2. Register it in the `MODULES` array in `provision.sh`.
3. Add a row to the module table in `README.md`.
4. Check it: `bash -n lib/NN-name.sh` and `shellcheck lib/NN-name.sh`.
5. Preview without changes: `./provision.sh --dry-run NN`.

## Before opening a PR

```bash
bash -n provision.sh lib/*.sh          # syntax
shellcheck provision.sh lib/*.sh       # lint (CI runs this at -S error)
./provision.sh --dry-run               # sanity-check the plan
```
