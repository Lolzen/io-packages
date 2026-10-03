#!/bin/sh
# mkrootfs.sh - install Io into a directory and pack it as io-rootfs.tar.zst,
# the source of both io.img (mkimg.sh) and the recovery image's payload
# (mkrecovery.sh).
#
# Usage:
#   sudo ./mkrootfs.sh           reuse an existing rootfs (asks; it is
#                                updated before the package list is installed)
#   sudo ./mkrootfs.sh --clean   start from an empty directory
#
# The tarball holds everything that does not depend on the disk Io lands
# on: packages, locales, users, services, GRUB's defaults. fstab, GRUB
# itself, the initramfs and the machine-id are made when it is unpacked.
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/config/system.conf"
require_root
parse_build_args "$@"
set_traps
ROOTHASH=$(openssl passwd -6 "$ROOTPASS")
USERHASH=$(openssl passwd -6 "$USERPASS")

build_system_rootfs() {
  confirm_existing "$SYS_ROOTFS" "system rootfs"
  rm -f -- "$ROOTFS_TARBALL"
  log "installing packages -> $SYS_ROOTFS"
  mkdir -p "$SYS_ROOTFS"
  install_pkgfile "$SYS_ROOTFS" "$SCRIPT_DIR/packages/system"
  # HOSTNAME is set by the config file (or the environment).
  # shellcheck disable=SC3028
  setup_identity "$SYS_ROOTFS" "$HOSTNAME" "$TIMEZONE" "$LANG_DEFAULT"
  grub_set_defaults "$SYS_ROOTFS" "$KERNEL_CMDLINE" "Io"
  bind_chroot "$SYS_ROOTFS"
  log "reconfiguring packages"
  chroot_reconfigure "$SYS_ROOTFS"
  log "generating locales"
  # shellcheck disable=SC2086
  enable_locales "$SYS_ROOTFS" $IO_LOCALES
  log "creating users"
  make_users "$SYS_ROOTFS" "$USERNAME" "$ROOTHASH" "$USERHASH" "$USERGROUPS"
  # wheel gets sudo through holo-sudo, as on SteamOS.
  log "verifying passwords"
  verify_passwords "$SYS_ROOTFS" "$USERNAME"
  log "enabling services"
  # shellcheck disable=SC2086
  enable_services "$SYS_ROOTFS" $SERVICES
  drop_elogind_dbus "$SYS_ROOTFS"
  unbind_chroot "$SYS_ROOTFS"
  clean_rootfs "$SYS_ROOTFS"
}

build_system_rootfs
log "packing $SYS_ROOTFS -> $ROOTFS_TARBALL"
pack_rootfs_tarball "$SYS_ROOTFS" "$ROOTFS_TARBALL"
own_as_invoker "$ROOTFS_TARBALL"
own_workdir "$WORKDIR"
echo
echo "built $ROOTFS_TARBALL"
ls -lh "$ROOTFS_TARBALL"
echo
echo "next:"
echo "  sudo ./mkimg.sh        (io.img from the tarball)"
echo "  sudo ./mkrecovery.sh   (recovery.img with the tarball as payload)"
