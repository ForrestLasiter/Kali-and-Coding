#!/usr/bin/env bash
# config.sh — tunables for the provisioning kit (sourced by provision.sh).
# Everything here has a sensible default and can also be overridden by env var,
# e.g.  KIT_NAME=mybox BAT_STOP=100 sudo ./provision.sh
#
# You do NOT set hardware here: CPU / GPU / laptop vendor are auto-detected by
# lib/60-hardware.sh, so the kit adapts to whatever machine it runs on.

# Name used for the run logfile: /var/log/<KIT_NAME>-<timestamp>.log
KIT_NAME="${KIT_NAME:-kali-setup}"

# Battery charge thresholds (%). Applied ONLY on laptops whose firmware exposes
# the interface (many ThinkPads, some Dell/others); silently skipped elsewhere.
# Set BAT_STOP=100 to disable charge limiting entirely.
BAT_START="${BAT_START:-75}"
BAT_STOP="${BAT_STOP:-80}"

# GPU driver policy:
#   auto   — open drivers/firmware for the detected GPU; NVIDIA only flagged
#   nvidia — also install the proprietary NVIDIA driver (use on NVIDIA laptops)
#   none   — skip GPU extras entirely
INSTALL_GPU_DRIVER="${INSTALL_GPU_DRIVER:-auto}"
