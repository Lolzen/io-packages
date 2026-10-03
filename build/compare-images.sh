#!/bin/sh
# compare-images.sh - compare two Io images file by file, e.g. before and
# after a change to the build. Nothing is written to either image (mounted
# read-only).
#
# Usage: sudo ./compare-images.sh OLD.img NEW.img [OUTDIR]
# Results in OUTDIR (default /tmp/imgcmp): one diff per aspect, and a
# summary on the terminal. Expected differences: fstab (LABEL= → UUID=),
# grub.cfg's UUIDs, the xbps package cache (gone in the new image),
# regenerated files like the initramfs.
set -eu
OLD=${1:-}; NEW=${2:-}; OUT=${3:-/tmp/imgcmp}
[ -f "$OLD" ] && [ -f "$NEW" ] || { echo "usage: $0 OLD.img NEW.img [OUTDIR]" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }
command -v getcap > /dev/null || { echo "getcap missing (libcap-progs)" >&2; exit 1; }
mkdir -p "$OUT"
L1=""; L2=""
cleanup() {
  set +e
  umount "$OUT/mnt-old/boot/efi" "$OUT/mnt-new/boot/efi" 2>/dev/null
  umount "$OUT/mnt-old" "$OUT/mnt-new" 2>/dev/null
  [ -n "$L1" ] && losetup -d "$L1"
  [ -n "$L2" ] && losetup -d "$L2"
}
trap cleanup EXIT INT TERM

L1=$(losetup --find --show --partscan --read-only "$OLD")
L2=$(losetup --find --show --partscan --read-only "$NEW")
udevadm settle 2>/dev/null || sleep 1
mkdir -p "$OUT/mnt-old" "$OUT/mnt-new"
mount -o ro "${L1}p2" "$OUT/mnt-old"
mount -o ro "${L2}p2" "$OUT/mnt-new"
mount -o ro "${L1}p1" "$OUT/mnt-old/boot/efi"
mount -o ro "${L2}p1" "$OUT/mnt-new/boot/efi"

# One manifest line per file: path, type and mode, owner, link target.
# Sizes are left out (regenerated files differ in size every build).
manifest() {
  (cd "$1" && find . -xdev -path ./var/cache/xbps -prune -o -printf '%p\t%M\t%U:%G\t%l\n' | LC_ALL=C sort)
}
for side in old new; do
  manifest "$OUT/mnt-$side" > "$OUT/files-$side.txt"
  (cd "$OUT/mnt-$side" && getcap -r . 2>/dev/null | LC_ALL=C sort) > "$OUT/caps-$side.txt"
  xbps-query -r "$OUT/mnt-$side" -l | awk '{print $2}' | LC_ALL=C sort > "$OUT/pkgs-$side.txt"
  grep -E '^\s*linux' "$OUT/mnt-$side/boot/grub/grub.cfg" | sed 's/UUID=[^ ]*/UUID=.../g' | LC_ALL=C sort -u > "$OUT/cmdline-$side.txt"
  cp "$OUT/mnt-$side/etc/fstab" "$OUT/fstab-$side.txt"
  # Contents where a lost setting would not show in the file list.
  for f in etc/group etc/passwd etc/default/grub etc/default/libc-locales etc/locale.conf etc/hostname etc/localtime; do
    printf '### %s\n' "$f"
    if [ -L "$OUT/mnt-$side/$f" ]; then readlink "$OUT/mnt-$side/$f"; else cat "$OUT/mnt-$side/$f" 2>/dev/null || echo "(missing)"; fi
  done > "$OUT/config-$side.txt"
  ls -l "$OUT/mnt-$side/usr/lib/locale/locale-archive" | awk '{print $5}' >> "$OUT/config-$side.txt"
  (cd "$OUT/mnt-$side/boot/efi" && find . -type f | LC_ALL=C sort) > "$OUT/esp-$side.txt"
  (cd "$OUT/mnt-$side" && du -sxh --exclude=./var/cache/xbps .) | cut -f1 > "$OUT/size-$side.txt"
done

echo "== results in $OUT"
for a in files caps pkgs cmdline fstab config esp; do
  if diff -u "$OUT/$a-old.txt" "$OUT/$a-new.txt" > "$OUT/$a.diff"; then
    echo "$a: same"
  else
    echo "$a: $(grep -c '^[-+][^-+]' "$OUT/$a.diff") changed lines, see $a.diff"
  fi
done
echo "used (without xbps cache): old $(cat "$OUT/size-old.txt"), new $(cat "$OUT/size-new.txt")"
echo "xbps cache in old image: $(du -sh "$OUT/mnt-old/var/cache/xbps" | cut -f1)"
