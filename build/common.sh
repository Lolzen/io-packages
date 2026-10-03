#!/bin/sh
# common.sh - shared functions for mkrootfs.sh, mkimg.sh and mkrecovery.sh.
# Sourced, not run.
#
# The build is split in two steps: mkrootfs.sh installs Io once into a
# directory and packs it as io-rootfs.tar.zst; mkimg.sh turns that tarball
# into io.img, and mkrecovery.sh puts it into recovery.img as the payload
# its installer writes to a disk. Everything that depends on the disk the
# system lands on (fstab, GRUB, initramfs) is done when the tarball is
# unpacked, not in the tarball. io-restore also gives each installation a
# machine-id of its own; io.img keeps the tarball's, as every image did.

set -eu
[ -n "${COMMON_SH_LOADED:-}" ] && return 0 2>/dev/null || true
COMMON_SH_LOADED=1
LOOP=""
MOUNTS=""

CLEAN_BUILD=0
parse_build_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --clean) CLEAN_BUILD=1 ;;
      -h|--help)
        printf 'Usage: %s [--clean]\n' "$(basename "$0")"
        exit 0
        ;;
      *) die "unknown option: $1 (use --clean or --help)" ;;
    esac
    shift
  done
}

# Ask before reusing an existing build artifact. With --clean it is removed.
# Returns 0 when the caller may go on with the existing one.
confirm_existing() {
  _path=$1; _desc=$2
  [ -e "$_path" ] || return 0
  if [ "$CLEAN_BUILD" = 1 ]; then
    printf '== removing existing %s: %s\n' "$_desc" "$_path"
    safe_remove "$_path"
    return 0
  fi
  printf '\nWARNING: %s already exists: %s\n' "$_desc" "$_path" >&2
  printf 'Consider --clean for a clean rebuild.\n' >&2
  printf 'Continue anyways? [y/N] ' >&2
  _answer=''
  IFS= read -r _answer < /dev/tty || die 'cannot read confirmation from terminal'
  case "$_answer" in
    y|Y|yes|YES|Yes) ;;
    *) die 'aborted; use --clean for a clean rebuild' ;;
  esac
}

log() { printf '== %s\n' "$*"; }

# rm -rf on a build root that still has /dev, /proc, /sys or /run bound into
# it (a build killed with the terminal) would delete the host's. Refuse
# while anything is mounted below it, and never cross into another
# filesystem.
safe_remove() {
  if findmnt -rno TARGET | grep -q -F "$1/"; then
    findmnt -rno TARGET | grep -F "$1/" >&2
    die "still mounted below $1 - unmount first (umount -R)"
  fi
  rm -rf --one-file-system -- "$1"
}
die() { printf '%s: %s\n' "$(basename "$0")" "$*" >&2; exit 1; }
require_root() { [ "$(id -u)" -eq 0 ] || die "must run as root"; }

# Every mount is recorded, newest first, so cleanup_all can undo them in
# reverse order when a step fails.
track_mount() { MOUNTS="$1 ${MOUNTS:-}"; }
untrack_mount() { MOUNTS=$(printf ' %s ' "${MOUNTS:-}" | sed "s# $1 # #"); }

attach_loop() {
  LOOP=$(losetup --find --show --partscan "$1")
  udevadm settle 2>/dev/null || sleep 1
}
cleanup_all() {
  set +e
  for m in ${MOUNTS:-}; do
    umount -R "$m" 2>/dev/null || printf 'WARNING: could not unmount %s\n' "$m" >&2
  done
  MOUNTS=""
  if [ -n "${LOOP:-}" ]; then losetup -d "$LOOP" 2>/dev/null; fi
  LOOP=""
}
# For the scripts: clean up on every way out, and stop on a signal instead
# of going on with the next command.
set_traps() {
  trap cleanup_all EXIT
  trap 'cleanup_all; exit 130' INT TERM HUP
}

make_empty_image() { rm -f "$1"; truncate -s "$2" "$1"; }

# GPT: 512M ESP, the rest ext4. sgdisk is scriptable; parted's interactive
# rounding warnings are not.
part_io_layout() {
  sgdisk --zap-all "$1" > /dev/null
  sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"$2" "$1" > /dev/null
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"$3" "$1" > /dev/null
}
# The same with a fixed size for the second partition (in sectors).
part_layout_p2size() {
  sgdisk --zap-all "$1" > /dev/null
  sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"$2" "$1" > /dev/null
  sgdisk -n "2:0:+$4" -t 2:8300 -c 2:"$3" "$1" > /dev/null
}
fmt_part() {
  case "$2" in
    vfat) mkfs.vfat -F32 -n "$3" "$1" > /dev/null ;;
    ext4) mkfs.ext4 -q -m "${4:-5}" -L "$3" "$1" ;;
    *) die "unknown fs $2" ;;
  esac
}
mount_part() { mkdir -p "$2"; mount "$1" "$2"; track_mount "$2"; }
umount_tracked() { umount -R "$1"; untrack_mount "$1"; }

# Bind the pseudo filesystems so chroot commands behave.
bind_chroot() {
  for d in dev proc sys run; do
    mkdir -p "$1/$d"
    mount --bind "/$d" "$1/$d"
    track_mount "$1/$d"
  done
}
unbind_chroot() {
  for d in run sys proc dev; do
    if [ -n "${MOUNTS:-}" ]; then
      case " $MOUNTS " in *" $1/$d "*) umount_tracked "$1/$d" ;; esac
    fi
  done
}

pkglist() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' | tr '\n' ' '; }
xbps_root() {
  # shellcheck disable=SC2086
  XBPS_ARCH=x86_64 xbps-install -y -R "$IO_REPO" -R "$VOID" -R "$VOID/nonfree" -R "$VOID/multilib" -R "$VOID/multilib/nonfree" "$@"
}
# Install the package list into a root. A root kept from an earlier build
# is brought up to date first: xbps-install without -u installs what is
# missing but leaves installed packages at their old version, and the
# tarball would quietly carry them. xbps updates itself first when needed.
install_pkgfile() {
  _pkgs=$(pkglist "$2")
  if [ -x "$1/usr/bin/xbps-install" ]; then
    log "updating the existing root first"
    xbps_root -S -u -r "$1" xbps
    xbps_root -S -u -r "$1"
  fi
  # shellcheck disable=SC2086
  xbps_root -S -r "$1" $_pkgs
}

# BUILD_ROOTFS=1 runs mkrootfs.sh first, BUILD_ROOTFS=clean runs it with
# --clean. The calling script's own --clean is not passed on: it removes
# only that script's results, never the system rootfs or its tarball.
maybe_build_rootfs() {
  case "${BUILD_ROOTFS:-0}" in
    0) ;;
    1) log "building rootfs tarball first"; "$SCRIPT_DIR/mkrootfs.sh" ;;
    clean) log "building rootfs tarball first (clean)"; "$SCRIPT_DIR/mkrootfs.sh" --clean ;;
    *) die "BUILD_ROOTFS=$BUILD_ROOTFS: use 1 or clean" ;;
  esac
}

# Configure any package the install step left unconfigured, now that /dev,
# /proc and /sys are there (normally none; void-mklive runs the same step).
chroot_reconfigure() {
  chroot "$1" xbps-reconfigure -a
}

setup_identity() {
  printf '%s\n' "$2" > "$1/etc/hostname"
  ln -sf "/usr/share/zoneinfo/$3" "$1/etc/localtime"
  # Only LANG, as on SteamOS (Void's default also sets LC_COLLATE=C).
  printf 'LANG=%s\n' "$4" > "$1/etc/locale.conf"
}

# Enable the UTF-8 locales given and have glibc-locales generate them. The
# reconfigure is forced: glibc-locales may already count as configured from
# the install step, and only its configure step generates them.
enable_locales() {
  _root=$1; shift
  for _loc in "$@"; do
    sed -i -E "s/^#[[:space:]]*(${_loc}(\\.UTF-8)? UTF-8)[[:space:]]*\$/\\1/" "$_root/etc/default/libc-locales"
  done
  chroot "$_root" xbps-reconfigure -f glibc-locales
}

# Hashed on the host with openssl and set with usermod -p, so nothing
# depends on crypt() inside the chroot.
make_users() {
  chroot "$1" usermod -p "$3" root
  if chroot "$1" id "$2" >/dev/null 2>&1; then
    chroot "$1" usermod -G "$5" "$2"
  else
    chroot "$1" useradd -m -G "$5" -s /bin/bash "$2"
  fi
  chroot "$1" usermod -p "$4" "$2"
}
# A missing hash would only show at the first password prompt (the
# autologin skips authentication), so check it here.
verify_passwords() {
  for _u in root "$2"; do
    _h=$(chroot "$1" awk -F: -v u="$_u" '$1 == u { print $2 }' /etc/shadow)
    case "$_h" in '$'*) ;; *) die "$_u has no valid password hash" ;; esac
  done
}

enable_services() {
  _root=$1; shift
  for _svc in "$@"; do
    if [ -d "$_root/etc/sv/$_svc" ]; then
      ln -sf "/etc/sv/$_svc" "$_root/etc/runit/runsvdir/default/"
    else
      printf '   %s: no such service, skipping\n' "$_svc" >&2
    fi
  done
}

# elogind ships both a runit service and a D-Bus activation file. Whichever
# loses the boot race retries every second forever. Removing the activation
# file leaves the runit service as the only way elogind starts; io-base's
# noextract keeps elogind updates from bringing it back.
drop_elogind_dbus() { rm -f "$1/usr/share/dbus-1/system-services/org.freedesktop.login1.service"; }

# Kernel command line and menu name go into the root's /etc/default/grub,
# so every grub-mkconfig on that system (the image, an installation, later
# kernel updates) uses them.
grub_set_defaults() {
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$2\"|" "$1/etc/default/grub"
  sed -i "s|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR=\"$3\"|" "$1/etc/default/grub"
  grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=\"$2\"\$" "$1/etc/default/grub" || die "kernel command line not set in /etc/default/grub"
}

# --removable puts the loader at EFI/BOOT/BOOTX64.EFI, which the Deck's
# firmware finds without an NVRAM entry. Without it the image would only
# boot on the machine that built it.
grub_install_removable() {
  chroot "$1" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$2" --removable --no-nvram
  [ -f "$1/boot/efi/EFI/BOOT/BOOTX64.EFI" ] || die "no EFI loader written"
}
grub_mkconfig() { chroot "$1" grub-mkconfig -o /boot/grub/grub.cfg; }

# The newest kernel: a reused root keeps the previous one next to it
# (linux-neptune-72 is preserve=yes), and GRUB boots the newest by default.
newest_kernel() { ls "$1/usr/lib/modules" | sort -V | tail -n 1; }
make_initramfs() {
  _kver=$(newest_kernel "$1")
  [ -n "$_kver" ] || die "no kernel modules in $1"
  printf '   kernel %s\n' "$_kver"
  chroot "$1" dracut --force --kver "$_kver" "/boot/initramfs-${_kver}.img"
}

# fstab by UUID of the filesystems just created. The labels (IOROOT, IOESP)
# are the same on every Io card and installation; with two of them plugged
# in, a LABEL= line could name the other one.
write_fstab() {
  _root_uuid=$(blkid -s UUID -o value "$2")
  _esp_uuid=$(blkid -s UUID -o value "$3")
  [ -n "$_root_uuid" ] && [ -n "$_esp_uuid" ] || die "no UUID for $2 or $3"
  cat > "$1/etc/fstab" << EOF
UUID=$_root_uuid  /          ext4  defaults              0 1
UUID=$_esp_uuid  /boot/efi  vfat  defaults,noatime      0 2
tmpfs  /tmp  tmpfs  defaults,nosuid,nodev  0 0
EOF
}

# Leave out what does not belong into a payload: xbps' package cache (the
# downloaded .xbps files, gigabytes) and shell history from the chroot.
clean_rootfs() {
  rm -rf "$1"/var/cache/xbps/*
  rm -f "$1/root/.bash_history"
}

# File capabilities are extended attributes (security.capability). GNU tar
# stores them with --xattrs, but restores only user.* unless told
# otherwise; without --xattrs-include='*' packages that setcap at install
# (iputils' ping, for one) would lose them.
pack_rootfs_tarball() {
  rm -f "$2"
  # Not piped into zstd: sh has no pipefail, a failing tar would go unseen.
  tar --zstd --xattrs --xattrs-include='*' --acls --numeric-owner -C "$1" -cf "$2" .
}
unpack_rootfs_tarball() {
  mkdir -p "$2"
  tar --zstd --xattrs --xattrs-include='*' --acls --numeric-owner -xf "$1" -C "$2"
}
require_tarball() { [ -f "$1" ] || die "no tarball $1 (run mkrootfs.sh first)"; }

size_to_bytes() {
  printf '%s' "$1" | grep -Eq '^[0-9]+[KkMmGgTt]?$' || die "size '$1': use a number with K, M, G or T (16G)"
  _n=${1%[KkMmGgTt]}
  case "$1" in
    *[Kk]) printf '%s' "$((_n * 1024))" ;;
    *[Mm]) printf '%s' "$((_n * 1024 * 1024))" ;;
    *[Gg]) printf '%s' "$((_n * 1024 * 1024 * 1024))" ;;
    *[Tt]) printf '%s' "$((_n * 1024 * 1024 * 1024 * 1024))" ;;
    *) printf '%s' "$_n" ;;
  esac
}

# The user who ran sudo gets the results, not root.
invoker_owner() {
  if [ -n "${SUDO_USER:-}" ]; then printf '%s' "$SUDO_USER"
  elif [ -n "${DOAS_USER:-}" ]; then printf '%s' "$DOAS_USER"
  else logname 2>/dev/null || whoami; fi
}
own_as_invoker() {
  _u=$(invoker_owner)
  _g=$(id -gn "$_u" 2>/dev/null || printf '%s' "$_u")
  for _f in "$@"; do
    [ -e "$_f" ] || continue
    chown "$_u:$_g" "$_f" 2>/dev/null || chown "$_u" "$_f" 2>/dev/null || true
  done
}
own_workdir() {
  _u=$(invoker_owner)
  _g=$(id -gn "$_u" 2>/dev/null || printf '%s' "$_u")
  [ -d "$1" ] || return 0
  chown "$_u:$_g" "$1" 2>/dev/null || true
  for _f in "$1"/*.img "$1"/*.tar.zst "$1"/*.sha256 "$1"/*.xz; do
    [ -e "$_f" ] || continue
    chown "$_u:$_g" "$_f" 2>/dev/null || true
  done
}

# Shrink an image to its used size plus a margin: smaller to write with dd,
# fits smaller cards. The filesystem is grown back to the partition end
# afterwards. Expects the image attached as $_loop with p2 unmounted.
trim_image() {
  _img=$1; _loop=$2; _margin_mb=${3:-256}; _label=$4
  log "shrinking $(basename "$_img") to minimum (+${_margin_mb}M)"
  e2fsck -f -y "${_loop}p2" > /dev/null 2>&1 || true
  resize2fs -M "${_loop}p2"
  _bs=$(dumpe2fs -h "${_loop}p2" 2>/dev/null | awk '/Block size:/{print $3}')
  _bc=$(dumpe2fs -h "${_loop}p2" 2>/dev/null | awk '/Block count:/{print $3}')
  _fsbytes=$((_bs*_bc))
  _start=$(sgdisk --info=2 "$_img" | awk '/First sector:/{print $3}')
  losetup -d "$_loop"
  LOOP=""
  _startbytes=$((_start*512))
  _marginbytes=$((_margin_mb*1024*1024))
  _newendbytes=$((_startbytes+_fsbytes+_marginbytes))
  _newendmb=$((_newendbytes/1024/1024+2))
  # The backup GPT takes the last 33 sectors.
  _newendsect=$((_newendmb*2048-34))
  # Recreating partition 2 gives it a new PARTUUID; nothing refers to it
  # (fstab and GRUB use the filesystem UUID, which stays).
  sgdisk -d 2 -n "2:${_start}:${_newendsect}" -c 2:"$_label" -t 2:8300 "$_img" > /dev/null
  truncate -s "${_newendmb}M" "$_img"
  # The backup GPT was cut off with the image's end; sgdisk complains about
  # it once, then writes it at the new end.
  sgdisk --move-second-header "$_img" > /dev/null 2>&1
  sgdisk --verify "$_img" > /dev/null
  attach_loop "$_img"
  e2fsck -f -y "${LOOP}p2" > /dev/null 2>&1 || true
  resize2fs "${LOOP}p2" > /dev/null
}
