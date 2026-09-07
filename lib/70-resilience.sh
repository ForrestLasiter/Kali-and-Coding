#!/usr/bin/env bash
# 70-resilience.sh — snapshots + encrypted backups.
# On a ROLLING distro, a snapshot before a big upgrade is your undo button.

info "Timeshift (system snapshots) + restic (encrypted backups)"
apt_install timeshift restic rsync

# Drop a tiny pre-upgrade snapshot helper so you actually take snapshots.
cat > /usr/local/bin/snap-before-upgrade <<'EOF'
#!/usr/bin/env bash
# Take a Timeshift snapshot, then full-upgrade. Roll back via Timeshift GUI/CLI.
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
timeshift --create --comments "pre-upgrade $(date +%F_%T)" --tags D
apt-get update && apt-get -y full-upgrade
echo "Upgrade done. If something broke: sudo timeshift --restore"
EOF
chmod +x /usr/local/bin/snap-before-upgrade
ok "installed helper: snap-before-upgrade"

# Drop a restic backup wrapper template (user fills in repo + password file).
cat > /usr/local/bin/backup-home <<'EOF'
#!/usr/bin/env bash
# Encrypted backup of $HOME with restic. Configure the two vars below first:
#   export RESTIC_REPOSITORY=...   (e.g. /mnt/backup/restic  or  sftp:user@host:/path
#                                    or  rest:https://...  — a drive on your homelab)
#   export RESTIC_PASSWORD_FILE=$HOME/.config/restic-pass   (chmod 600)
set -euo pipefail
: "${RESTIC_REPOSITORY:?set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD_FILE:?set RESTIC_PASSWORD_FILE}"
restic backup "$HOME" \
  --exclude "$HOME/.cache" \
  --exclude "$HOME/Downloads" \
  --exclude "$HOME/.local/share/Trash" \
  --exclude-caches
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
EOF
chmod +x /usr/local/bin/backup-home
ok "installed template: backup-home (edit repo + password before first use)"

cat <<EOF
${_c_blue}[*]${_c_reset} Timeshift: launch it once (GUI) and pick RSYNC mode + a target disk.
    For a rolling distro, snapshot BEFORE upgrades:  sudo snap-before-upgrade
${_c_blue}[*]${_c_reset} restic: init a repo once, then run backup-home on a schedule:
      restic init                      # after exporting RESTIC_REPOSITORY
      backup-home                      # add to a systemd timer / cron for auto
${_c_yellow}[!]${_c_reset} Timeshift is NOT a substitute for restic — snapshots live on-disk and
    won't survive drive loss/theft. Keep restic backups OFF the laptop.
EOF

ok "resilience module complete"
