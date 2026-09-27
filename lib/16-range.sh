#!/usr/bin/env bash
# 16-range.sh — "Practice Range": a one-command deliberately-vulnerable lab.
#
# Builds on 15-vmlab (KVM/libvirt) and the Docker install from 10-dev. Installs
# the `range` CLI and creates an ISOLATED libvirt network so vulnerable targets
# have no route to your LAN or the internet. Nothing large is downloaded here —
# target images are pulled/imported on first `range up`.

info "Practice Range (isolated vulnerable-target lab)"

# The range leans on Docker (web apps) and libvirt (VMs). Both are installed by
# earlier modules; warn (don't fail) if a run skipped them.
command -v docker >/dev/null 2>&1 || warn "docker not found (module 10-dev) — Docker targets in 'range' will be unavailable until it's installed"
command -v virsh  >/dev/null 2>&1 || warn "virsh not found (module 15-vmlab) — VM targets in 'range' will be unavailable until it's installed"

# --- isolated libvirt network ----------------------------------------------
# No <forward> element => an ISOLATED network: guests can talk to each other and
# to the host, but have NO NAT/route to the LAN or the internet. Exactly what a
# deliberately-vulnerable box should be confined to. 192.168.66.0/24 is picked
# to avoid clashing with libvirt's default 192.168.122.0/24.
if command -v virsh >/dev/null 2>&1; then
  if virsh -c qemu:///system net-info range >/dev/null 2>&1; then
    ok "libvirt isolated network 'range' already defined"
  else
    tmpnet="$(mktemp)"
    cat > "$tmpnet" <<'EOF'
<network>
  <name>range</name>
  <bridge name='virbr-range' stp='on' delay='0'/>
  <ip address='192.168.66.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.66.100' end='192.168.66.199'/>
    </dhcp>
  </ip>
</network>
EOF
    if virsh -c qemu:///system net-define "$tmpnet" >/dev/null 2>&1; then
      virsh -c qemu:///system net-autostart range >/dev/null 2>&1 || true
      virsh -c qemu:///system net-start range >/dev/null 2>&1 || true
      ok "created isolated libvirt network 'range' (192.168.66.0/24, no internet route)"
    else
      warn "could not define libvirt 'range' network — VM targets may not isolate correctly"
    fi
    rm -f "$tmpnet"
  fi
fi

# --- install the `range` CLI -------------------------------------------------
cat > /usr/local/bin/range <<'RANGE_EOF'
#!/usr/bin/env bash
# range — one-command deliberately-vulnerable practice lab on an ISOLATED
# network. Part of the kali-setup kit (module 16-range).
#
#   range up <target>        start a target (see 'range list')
#   range down [target]      stop one target, or all if omitted
#   range reset <target>     wipe a target back to a clean state
#   range status             what's running and how to reach it
#   range list               available targets
#   range import <t> <path>  import a downloaded VM image (e.g. metasploitable2)
#
# SAFETY: Docker targets are published to loopback (127.0.0.1) ONLY and run on a
# Docker network with no outbound route; VM targets sit on an isolated libvirt
# network with no NAT to your LAN or the internet. These boxes are INTENTIONALLY
# insecure — never move them onto a network you don't fully control.
set -euo pipefail

RANGE_SUBNET="192.168.66"
DOCKER_NET="range"
LIBVIRT_NET="range"
IMG_DIR="/var/lib/libvirt/images"

c_reset=$'\033[0m'; c_b=$'\033[1;34m'; c_g=$'\033[1;32m'; c_y=$'\033[1;33m'; c_r=$'\033[1;31m'
info(){ echo "${c_b}[*]${c_reset} $*"; }
ok(){   echo "${c_g}[+]${c_reset} $*"; }
warn(){ echo "${c_y}[!]${c_reset} $*" >&2; }
die(){  echo "${c_r}[x]${c_reset} $*" >&2; exit 1; }

# docker/virsh may need sudo depending on group membership; probe once.
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi
VIRSH=(virsh -c qemu:///system)
if ! "${VIRSH[@]}" list >/dev/null 2>&1; then VIRSH=(sudo virsh -c qemu:///system); fi

have_docker(){ command -v docker >/dev/null 2>&1; }
have_virsh(){  command -v virsh  >/dev/null 2>&1; }

# Docker-backed targets: name -> "image|hostport:containerport". Published to
# 127.0.0.1 only and attached to an internal (no-egress) docker network.
declare -A D_IMAGE=(
  [juice-shop]="bkimminich/juice-shop"
  [dvwa]="ghcr.io/digininja/dvwa:latest"
)
declare -A D_PORT=(
  [juice-shop]="3000:3000"
  [dvwa]="8080:80"
)
declare -A D_DESC=(
  [juice-shop]="OWASP Juice Shop — modern vulnerable web app"
  [dvwa]="Damn Vulnerable Web Application (PHP/MySQL)"
)
# VM-backed targets (imported, not auto-downloaded).
declare -A V_DESC=(
  [metasploitable2]="Classic vulnerable Linux box (import the VMware image)"
)

is_docker_target(){ [[ -n "${D_IMAGE[$1]:-}" ]]; }
is_vm_target(){     [[ -n "${V_DESC[$1]:-}"  ]]; }

ensure_docker_net(){
  "${DOCKER[@]}" network inspect "$DOCKER_NET" >/dev/null 2>&1 && return 0
  # --internal: containers on this network get NO route out (no phoning home,
  # no pivoting to the internet). Published loopback ports still work.
  "${DOCKER[@]}" network create --internal "$DOCKER_NET" >/dev/null \
    && ok "created isolated docker network '$DOCKER_NET' (no egress)"
}

ensure_libvirt_net(){
  have_virsh || return 0
  "${VIRSH[@]}" net-info "$LIBVIRT_NET" >/dev/null 2>&1 && { \
    "${VIRSH[@]}" net-start "$LIBVIRT_NET" >/dev/null 2>&1 || true; return 0; }
  die "isolated libvirt network '$LIBVIRT_NET' is missing — re-run module 16-range, or define it in virt-manager"
}

banner(){
  echo "${c_y}┌────────────────────────────────────────────────────────────────┐${c_reset}"
  echo "${c_y}│  These are INTENTIONALLY VULNERABLE targets on an isolated net. │${c_reset}"
  echo "${c_y}│  Reachable only from this machine. Never expose them to a LAN. │${c_reset}"
  echo "${c_y}└────────────────────────────────────────────────────────────────┘${c_reset}"
}

up_docker(){
  local t="$1" img="${D_IMAGE[$1]}" pmap="${D_PORT[$1]}"
  have_docker || die "docker is not installed"
  ensure_docker_net
  local cname="range-$t"
  if "${DOCKER[@]}" ps --format '{{.Names}}' | grep -qx "$cname"; then
    ok "$t already running"; return 0
  fi
  "${DOCKER[@]}" rm -f "$cname" >/dev/null 2>&1 || true
  info "pulling $img (first run only)…"
  "${DOCKER[@]}" pull "$img" >/dev/null 2>&1 || warn "pull failed — using local image if present"
  info "starting $t"
  "${DOCKER[@]}" run -d --name "$cname" \
    --network "$DOCKER_NET" \
    -p "127.0.0.1:${pmap}" \
    --restart unless-stopped \
    "$img" >/dev/null
  local hostport="${pmap%%:*}"
  ok "$t up  →  http://127.0.0.1:${hostport}"
}

up_vm(){
  local t="$1" dom="range-$t"
  have_virsh || die "libvirt is not installed"
  ensure_libvirt_net
  "${VIRSH[@]}" dominfo "$dom" >/dev/null 2>&1 \
    || die "$t not imported yet — run:  range import $t <path-to-image>"
  if "${VIRSH[@]}" domstate "$dom" 2>/dev/null | grep -q running; then
    ok "$t already running"
  else
    "${VIRSH[@]}" start "$dom" >/dev/null && ok "$t started"
  fi
  info "find its IP with:  range status   (leases on ${RANGE_SUBNET}.0/24)"
}

cmd_up(){
  local t="${1:-}"; [[ -n "$t" ]] || die "usage: range up <target>   (see 'range list')"
  if is_docker_target "$t"; then banner; up_docker "$t"
  elif is_vm_target "$t";   then banner; up_vm "$t"
  elif [[ "$t" == "ad-lab" ]]; then
    banner
    cat <<'MSG'
ad-lab is a guided setup, not a single container (a real AD needs a Windows DC).
The isolated 'range' libvirt network is ready for it. Recommended lightweight path:
  - GOAD-light / vulnAD, or a single Windows Server eval VM as a domain controller
  - attach every AD VM to the 'range' network so it stays isolated
Full walkthrough:  /usr/share/doc/kali-setup/RANGE.md  (and docs/RANGE.md in the repo)
MSG
  else
    die "unknown target '$t' (see 'range list')"
  fi
}

cmd_down(){
  local t="${1:-}"
  if [[ -z "$t" ]]; then
    info "stopping all range targets"
    if have_docker; then
      "${DOCKER[@]}" ps --format '{{.Names}}' | grep '^range-' | while read -r c; do
        "${DOCKER[@]}" stop "$c" >/dev/null && ok "stopped $c"
      done
    fi
    if have_virsh; then
      "${VIRSH[@]}" list --name 2>/dev/null | grep '^range-' | while read -r d; do
        "${VIRSH[@]}" shutdown "$d" >/dev/null 2>&1 && ok "shutting down $d"
      done
    fi
    return 0
  fi
  if is_docker_target "$t"; then
    "${DOCKER[@]}" stop "range-$t" >/dev/null 2>&1 && ok "stopped $t" || warn "$t was not running"
  elif is_vm_target "$t"; then
    "${VIRSH[@]}" shutdown "range-$t" >/dev/null 2>&1 && ok "shutting down $t" || warn "$t was not running"
  else
    die "unknown target '$t'"
  fi
}

cmd_reset(){
  local t="${1:-}"; [[ -n "$t" ]] || die "usage: range reset <target>"
  if is_docker_target "$t"; then
    info "resetting $t to a clean state"
    "${DOCKER[@]}" rm -f "range-$t" >/dev/null 2>&1 || true
    up_docker "$t"
  elif is_vm_target "$t"; then
    local dom="range-$t"
    "${VIRSH[@]}" dominfo "$dom" >/dev/null 2>&1 || die "$t not imported"
    if "${VIRSH[@]}" snapshot-info "$dom" range-clean >/dev/null 2>&1; then
      "${VIRSH[@]}" destroy "$dom" >/dev/null 2>&1 || true
      "${VIRSH[@]}" snapshot-revert "$dom" range-clean --force >/dev/null \
        && ok "$t reverted to 'range-clean' snapshot"
    else
      die "no 'range-clean' snapshot for $t (created automatically at import time)"
    fi
  else
    die "unknown target '$t'"
  fi
}

cmd_status(){
  echo "${c_b}== Docker targets ==${c_reset}"
  if have_docker; then
    local any=0
    for t in "${!D_IMAGE[@]}"; do
      if "${DOCKER[@]}" ps --format '{{.Names}}' | grep -qx "range-$t"; then
        printf '  %-14s running   http://127.0.0.1:%s\n' "$t" "${D_PORT[$t]%%:*}"; any=1
      fi
    done
    [[ $any -eq 0 ]] && echo "  (none running)"
  else
    echo "  docker not installed"
  fi
  echo "${c_b}== VM targets ==${c_reset}"
  if have_virsh; then
    local vany=0
    while read -r d; do
      [[ -n "$d" ]] || continue
      printf '  %-20s running\n' "${d#range-}"; vany=1
    done < <("${VIRSH[@]}" list --name 2>/dev/null | grep '^range-' || true)
    [[ $vany -eq 0 ]] && echo "  (none running)"
    echo "${c_b}== isolated-net DHCP leases (${RANGE_SUBNET}.0/24) ==${c_reset}"
    "${VIRSH[@]}" net-dhcp-leases "$LIBVIRT_NET" 2>/dev/null | sed -n '1,3p;/'"$RANGE_SUBNET"'/p' || echo "  (none)"
  else
    echo "  libvirt not installed"
  fi
}

cmd_list(){
  echo "${c_b}Docker targets${c_reset} (start instantly, loopback-only):"
  for t in "${!D_IMAGE[@]}"; do printf '  %-14s %s\n' "$t" "${D_DESC[$t]}"; done
  echo "${c_b}VM targets${c_reset} (import a downloaded image first):"
  for t in "${!V_DESC[@]}"; do printf '  %-14s %s\n' "$t" "${V_DESC[$t]}"; done
  echo "${c_b}Guided${c_reset}:"
  printf '  %-14s %s\n' "ad-lab" "Lightweight Active Directory lab — see docs/RANGE.md"
}

cmd_import(){
  local t="${1:-}" src="${2:-}"
  [[ -n "$t" && -n "$src" ]] || die "usage: range import <target> <path-to-image-or-dir>"
  is_vm_target "$t" || die "'$t' is not a VM target (import is for VM images)"
  have_virsh || die "libvirt is not installed"
  [[ -e "$src" ]] || die "no such path: $src"
  ensure_libvirt_net
  local dom="range-$t"
  "${VIRSH[@]}" dominfo "$dom" >/dev/null 2>&1 && die "$t already imported (range reset $t to clean it)"

  # Locate a disk image inside the source (Metasploitable ships a .vmdk).
  local disk
  if [[ -d "$src" ]]; then
    disk="$(find "$src" -maxdepth 2 -iname '*.vmdk' -o -iname '*.qcow2' -o -iname '*.img' 2>/dev/null | head -1)"
  else
    disk="$src"
  fi
  [[ -n "$disk" && -f "$disk" ]] || die "could not find a .vmdk/.qcow2/.img under $src"

  local qcow="$IMG_DIR/${dom}.qcow2"
  info "converting $(basename "$disk") -> $qcow"
  sudo qemu-img convert -O qcow2 "$disk" "$qcow" || die "qemu-img convert failed"

  info "defining VM '$dom' on isolated network '$LIBVIRT_NET'"
  sudo virt-install --connect qemu:///system \
    --name "$dom" --memory 1024 --vcpus 1 \
    --disk "path=$qcow,format=qcow2,bus=ide" \
    --network "network=$LIBVIRT_NET" \
    --os-variant generic --graphics vnc \
    --import --noautoconsole \
    || die "virt-install failed"

  # snapshot the clean state so 'range reset' can return to it
  "${VIRSH[@]}" snapshot-create-as "$dom" range-clean "clean import" >/dev/null 2>&1 \
    && ok "snapshot 'range-clean' created"
  ok "$t imported. Start it with:  range up $t"
}

case "${1:-}" in
  up)     shift; cmd_up "$@" ;;
  down)   shift; cmd_down "$@" ;;
  reset)  shift; cmd_reset "$@" ;;
  status) cmd_status ;;
  list|ls) cmd_list ;;
  import) shift; cmd_import "$@" ;;
  ""|help|-h|--help)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '$1' (try: range help)" ;;
esac
RANGE_EOF
chmod +x /usr/local/bin/range
ok "installed 'range' CLI  →  range list"

# ship the docs alongside the tool so 'range up ad-lab' can point at them
if [[ -f "$SCRIPT_DIR/docs/RANGE.md" ]]; then
  install -d /usr/share/doc/kali-setup
  install -m 0644 "$SCRIPT_DIR/docs/RANGE.md" /usr/share/doc/kali-setup/RANGE.md 2>/dev/null || true
fi

ok "range module complete"
