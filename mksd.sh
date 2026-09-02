#!/bin/sh
set -eu

DEV="${1:?usage: mksd.sh /dev/mmcblk0}"
MNT=/mnt/iosd
VOID=https://repo-default.voidlinux.org/current
REPO="$HOME/void-packages/hostdir/binpkgs"

case "$DEV" in
    *mmcblk*|*nvme*) P1="${DEV}p1"; P2="${DEV}p2" ;;
    *) P1="${DEV}1"; P2="${DEV}2" ;;
esac

echo "ACHTUNG: $DEV wird komplett geloescht."
lsblk -o NAME,SIZE,MODEL "$DEV"
printf "weiter? (yes) "
read answer
[ "$answer" = "yes" ] || exit 1

wipefs -a "$DEV"
sfdisk "$DEV" <<EOF
label: gpt
size=512M, type=uefi, name=IOESP
type=linux, name=IOROOT
EOF

sleep 2
mkfs.vfat -F32 -n IOESP "$P1"
mkfs.ext4 -F -L IOROOT "$P2"

mkdir -p "$MNT"
mount "$P2" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "$P1" "$MNT/boot/efi"

XBPS_ARCH=x86_64 xbps-install -Sy -R "$REPO -R "$VOID" -r "$MNT" base-system linux-neptune
XBPS_ARCH=x86_64 xbps-install -y -R "$REPO -R "$VOID" -r "$MNT" dracut grub-x86_64-efi efibootmgr
XBPS_ARCH=x86_64 xbps-install -y -R "$REPO -R "$VOID" -r "$MNT" NetworkManager linux-firmware-amd
XBPS_ARCH=x86_64 xbps-remove -y -r "$MNT" linux

echo "LABEL=IOROOT / ext4 defaults 0 1" > "$MNT/etc/fstab"
echo "LABEL=IOESP /boot/efi vfat defaults 0 2" >> "$MNT/etc/fstab"
echo "io" > "$MNT/etc/hostname"

mkdir -p "$MNT/etc/dracut.conf.d"
printf 'hostonly=no\nforce_drivers+=" amdgpu "\n' > "$MNT/etc/dracut.conf.d/10-io.conf"

for d in dev proc sys; do
    mount --rbind "/$d" "$MNT/$d"
    mount --make-rslave "$MNT/$d"
done

echo "---"
echo "fertig. jetzt: chroot $MNT /bin/bash"