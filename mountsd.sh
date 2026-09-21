#!/bin/sh
# mountsd.sh - mount an Io card on the build host and prepare a chroot,
# for repairs without booting the Deck.
#
# Usage: sudo ./mountsd.sh /dev/sdX      (or /dev/mmcblk0)
set -eu
MNT=/mnt/iosd
DEV="${1:?usage: mountsd.sh /dev/sdX}"

case "$DEV" in
    *mmcblk*|*nvme*) P1="${DEV}p1"; P2="${DEV}p2" ;;
    *) P1="${DEV}1"; P2="${DEV}2" ;;
esac

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount "$P2" "$MNT"
mkdir -p "$MNT/boot/efi"
mountpoint -q "$MNT/boot/efi" || mount "$P1" "$MNT/boot/efi"

for d in dev proc sys; do
    mountpoint -q "$MNT/$d" && continue
    mount --rbind "/$d" "$MNT/$d"
    mount --make-rslave "$MNT/$d"
done

echo "ready: chroot $MNT /bin/bash"
