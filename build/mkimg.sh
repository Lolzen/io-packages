#!/bin/sh
# mkimg.sh - build io.img, the ready-to-write Io disk image, from
# io-rootfs.tar.zst (mkrootfs.sh).
#
# Io ships as a disk image: the hardware is fixed, the partition layout is
# fixed, and writing the image with dd is the whole installation.
#
# Usage:
#   sudo ./mkimg.sh                      io.img from the existing tarball
#   sudo BUILD_ROOTFS=1 ./mkimg.sh       run mkrootfs.sh first (clean: with
#                                        --clean); --clean here only
#                                        removes io.img, never the rootfs
#   sudo SIZE=24G ./mkimg.sh             larger image
#   sudo TRIM=1 ./mkimg.sh               shrink to the contents plus
#                                        TRIM_MARGIN_MB (see system.conf)
#
# The image has two partitions: a 512M EFI system partition (IOESP) and an
# ext4 root (IOROOT). GRUB is installed in removable mode, so the firmware
# finds it without an NVRAM entry - which is what the Steam Deck needs.
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/config/system.conf"
require_root
parse_build_args "$@"
set_traps

pack_system_image() {
  log "creating $OUT ($SIZE)"
  make_empty_image "$OUT" "$SIZE"
  log "partitioning"
  part_io_layout "$OUT" "$ESP_LABEL" "$ROOT_LABEL"
  attach_loop "$OUT"
  echo "   $LOOP"
  log "formatting"
  fmt_part "${LOOP}p1" vfat "$ESP_LABEL"
  fmt_part "${LOOP}p2" ext4 "$ROOT_LABEL"
  log "mounting"
  mount_part "${LOOP}p2" "$MNT"
  # Unpacked before the ESP is mounted: tar would otherwise try to set
  # owner and mode on the vfat mount point. The rootfs has nothing in
  # /boot/efi (GRUB is installed below).
  log "unpacking $ROOTFS_TARBALL -> $MNT"
  unpack_rootfs_tarball "$ROOTFS_TARBALL" "$MNT"
  mkdir -p "$MNT/boot/efi"
  mount "${LOOP}p1" "$MNT/boot/efi"
  track_mount "$MNT/boot/efi"
  write_fstab "$MNT" "${LOOP}p2" "${LOOP}p1"
  bind_chroot "$MNT"
  # The initramfs first: grub-mkconfig only lists the initramfs files it
  # finds.
  log "generating initramfs"
  make_initramfs "$MNT"
  log "installing bootloader"
  grub_install_removable "$MNT" "$BOOTLOADER_ID"
  grub_mkconfig "$MNT"
  unbind_chroot "$MNT"
  umount_tracked "$MNT/boot/efi"
  umount_tracked "$MNT"
  if [ "${TRIM:-0}" = 1 ]; then
    trim_image "$OUT" "$LOOP" "$TRIM_MARGIN_MB" "$ROOT_LABEL"
  fi
  losetup -d "$LOOP"
  LOOP=""
  own_as_invoker "$OUT"
  own_workdir "$WORKDIR"
}

maybe_build_rootfs
require_tarball "$ROOTFS_TARBALL"
confirm_existing "$OUT" "system image"
pack_system_image
echo
echo "built $OUT (from $ROOTFS_TARBALL)"
ls -lh "$OUT"
echo
echo "write with:"
echo "  dd if=$OUT of=/dev/sdX bs=4M status=progress conv=fsync"
echo "for a release: xz-compress, split and checksum it as README's"
echo "Installation section expects (io.img.xz.part*, io.img.xz.sha256)"
echo
echo "login: $USERNAME / $USERPASS   (root / $ROOTPASS)"
