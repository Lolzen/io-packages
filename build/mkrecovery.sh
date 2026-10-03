#!/bin/sh
# mkrecovery.sh - build recovery.img: a small writable Void system with
# Plasma that boots from a USB drive and installs Io from the payload it
# carries (io-rootfs.tar.zst from mkrootfs.sh).
#
# Usage:
#   sudo ./mkrecovery.sh                     reuse existing roots (asks)
#   sudo ./mkrecovery.sh --clean             clean rebuild
#   sudo BUILD_ROOTFS=1 ./mkrecovery.sh      run mkrootfs.sh first
#
# A plain ext4 root instead of a live ISO: self-built void-mklive ISOs stop
# in dracut's emergency shell, and a recovery system that can be written to
# is easier to fix in place. It only has to boot to a desktop from which
# the install scripts run, so its passwords are known on purpose (see
# config/recovery.conf).
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/config/recovery.conf"
require_root
parse_build_args "$@"
set_traps
ROOTHASH=$(openssl passwd -6 "$REC_ROOTPASS")
USERHASH=$(openssl passwd -6 "$REC_USERPASS")

build_recovery_rootfs() {
  confirm_existing "$REC_ROOTFS" "recovery rootfs"
  log "installing recovery packages -> $REC_ROOTFS"
  mkdir -p "$REC_ROOTFS"
  install_pkgfile "$REC_ROOTFS" "$SCRIPT_DIR/packages/recovery"
  # HOSTNAME is set by the config file (or the environment).
  # shellcheck disable=SC3028
  setup_identity "$REC_ROOTFS" "$HOSTNAME" "$TIMEZONE" "$LANG_DEFAULT"
  grub_set_defaults "$REC_ROOTFS" "$KERNEL_CMDLINE" "Io-recovery"
  bind_chroot "$REC_ROOTFS"
  chroot_reconfigure "$REC_ROOTFS"
  log "creating recovery user: $REC_USER"
  # Known passwords: the console stays usable if SDDM does not start.
  make_users "$REC_ROOTFS" "$REC_USER" "$ROOTHASH" "$USERHASH" "$REC_GROUPS"
  verify_passwords "$REC_ROOTFS" "$REC_USER"

  log "configuring passwordless sudo"
  mkdir -p "$REC_ROOTFS/etc/sudoers.d"
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$REC_USER" > "$REC_ROOTFS/etc/sudoers.d/iorecovery"
  chmod 0440 "$REC_ROOTFS/etc/sudoers.d/iorecovery"

  log "configuring SDDM autologin"
  mkdir -p "$REC_ROOTFS/etc/sddm.conf.d"
  # The greeter on Wayland, as Io's own SDDM setup: SDDM defaults to X11,
  # and the recovery system has no X server. Without this, a failed
  # autologin or a logout leaves a black screen.
  cat > "$REC_ROOTFS/etc/sddm.conf.d/autologin.conf" << EOF_SDDM
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1

[Autologin]
User=$REC_USER
Session=plasma
Relogin=false
EOF_SDDM

  # shellcheck disable=SC2086
  enable_services "$REC_ROOTFS" $SERVICES
  [ -L "$REC_ROOTFS/etc/runit/runsvdir/default/sddm" ] || die "sddm service was not enabled"
  drop_elogind_dbus "$REC_ROOTFS"

  log "installing recovery tools"
  for _t in io-restore io-install io-repair; do
    install -m 0755 "$SCRIPT_DIR/recovery/$_t" "$REC_ROOTFS/usr/sbin/$_t"
  done
  _desk="$REC_ROOTFS/home/$REC_USER/Desktop"
  mkdir -p "$_desk"
  # Executable, or Plasma asks before it runs a desktop file.
  install -m 0755 "$SCRIPT_DIR/recovery/Install-Io.desktop" "$_desk/"
  install -m 0755 "$SCRIPT_DIR/recovery/Repair-Io.desktop" "$_desk/"
  chroot "$REC_ROOTFS" chown -R "$REC_USER:$REC_USER" "/home/$REC_USER/Desktop"

  unbind_chroot "$REC_ROOTFS"
  clean_rootfs "$REC_ROOTFS"
}

construct_recovery_image() {
  # Size: recovery system + payload + 2 % + margin, plus the 512M ESP.
  _rec_bytes=$(du -sb "$REC_ROOTFS" | cut -f1)
  _tar_bytes=$(stat -c%s "$ROOTFS_TARBALL")
  _margin_mb=${REC_MARGIN_MB:-512}
  _p2need=$(( _rec_bytes + _tar_bytes + (_rec_bytes + _tar_bytes) / 50 + (_margin_mb + 256) * 1024 * 1024 ))
  _p2sectors=$(( (_p2need + 511) / 512 ))
  _totalmb=$(( ((1050624 + _p2sectors + 34 + 2048) * 512 + 1048575) / 1048576 ))
  _exact=0
  if [ "$SIZE" = auto ]; then
    SIZE="${_totalmb}M"
    _exact=1
    log "auto size: recovery + payload + margin -> $SIZE"
  else
    _sizebytes=$(size_to_bytes "$SIZE")
    if [ $(( _totalmb * 1024 * 1024 )) -gt "$_sizebytes" ]; then
      die "SIZE=$SIZE too small, need at least ${_totalmb}M (or SIZE=auto)"
    fi
  fi
  log "creating $OUT ($SIZE)"
  make_empty_image "$OUT" "$SIZE"
  if [ "$_exact" = 1 ]; then
    part_layout_p2size "$OUT" "$ESP_LABEL" "$REC_LABEL" "$_p2sectors"
  else
    part_io_layout "$OUT" "$ESP_LABEL" "$REC_LABEL"
  fi
  attach_loop "$OUT"
  echo "   $LOOP"
  fmt_part "${LOOP}p1" vfat "$ESP_LABEL"
  fmt_part "${LOOP}p2" ext4 "$REC_LABEL" 1
  mount_part "${LOOP}p2" "$MNT"
  log "copying $REC_ROOTFS -> $MNT"
  # cp -a keeps owners, modes, ACLs and every xattr (file capabilities
  # included); a tar pipe would hide a failing first tar (no pipefail).
  cp -a "$REC_ROOTFS/." "$MNT/"
  log "copying $ROOTFS_TARBALL -> $MNT/$PAYLOAD_PATH"
  mkdir -p "$MNT/$(dirname "$PAYLOAD_PATH")"
  cp "$ROOTFS_TARBALL" "$MNT/$PAYLOAD_PATH"
  mkdir -p "$MNT/boot/efi"
  mount "${LOOP}p1" "$MNT/boot/efi"
  track_mount "$MNT/boot/efi"
  df -h "$MNT" | awk 'NR==2 { print "   " $3 " used of " $2 " (" $5 ")" }'
  write_fstab "$MNT" "${LOOP}p2" "${LOOP}p1"
  bind_chroot "$MNT"
  make_initramfs "$MNT"
  grub_install_removable "$MNT" "$BOOTLOADER_ID"
  grub_mkconfig "$MNT"
  unbind_chroot "$MNT"
  umount_tracked "$MNT/boot/efi"
  umount_tracked "$MNT"
  if [ "${TRIM:-0}" = 1 ]; then
    trim_image "$OUT" "$LOOP" "$TRIM_MARGIN_MB" "$REC_LABEL"
  fi
  losetup -d "$LOOP"
  LOOP=""
  own_as_invoker "$OUT"
  own_workdir "$WORKDIR"
}

if [ "${BUILD_ROOTFS:-0}" = 1 ]; then
  log "building rootfs tarball first"
  if [ "$CLEAN_BUILD" = 1 ]; then
    "$SCRIPT_DIR/mkrootfs.sh" --clean
  else
    "$SCRIPT_DIR/mkrootfs.sh"
  fi
fi
# Checked before the long recovery rootfs build, not after it.
require_tarball "$ROOTFS_TARBALL"
confirm_existing "$OUT" "recovery image"
build_recovery_rootfs
construct_recovery_image
echo
echo "built $OUT (payload: $PAYLOAD_PATH from $ROOTFS_TARBALL)"
ls -lh "$OUT"
echo
echo "write to a USB drive with:"
echo "  dd if=$OUT of=/dev/sdX bs=4M status=progress conv=fsync"
echo
echo "login: $REC_USER / $REC_USERPASS   (root / $REC_ROOTPASS)"
