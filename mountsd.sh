#!/bin/sh
set -eu
MNT=/mnt/iosd
DEV="${1:-/dev/sdd}"

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount "${DEV}2" "$MNT"
mkdir -p "$MNT/boot/efi"
mountpoint -q "$MNT/boot/efi" || mount "${DEV}1" "$MNT/boot/efi"

for d in dev proc sys; do
    mountpoint -q "$MNT/$d" && continue
    mount --rbind "/$d" "$MNT/$d"
    mount --make-rslave "$MNT/$d"
done

echo "bereit: chroot $MNT /bin/bash"