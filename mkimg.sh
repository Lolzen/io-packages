#!/bin/sh
# mkimg.sh - build a ready-to-write Io disk image.
#
# Io ships as a disk image rather than a live ISO: the hardware is fixed, the
# partition layout is fixed, and there is nothing for an installer to ask.
# Writing the image with dd is the whole installation.
#
# (The live-ISO route is blocked anyway: dracut 112 changed its live-boot
# logic and void-mklive has not caught up, so self-built ISOs drop to an
# emergency shell. See docs/ for details.)
#
# Usage:
#   sudo ./mkimg.sh                 build io.img (default size)
#   sudo SIZE=16G ./mkimg.sh        larger image
#   sudo OUT=/tmp/test.img ./mkimg.sh
#
# The image has two partitions: a 512M EFI system partition (IOESP) and an
# ext4 root (IOROOT). GRUB is installed in removable mode, so the firmware
# finds it without an NVRAM entry - which is what the Steam Deck needs.

set -eu

OUT="${OUT:-$HOME/io.img}"
SIZE="${SIZE:-12G}"
MNT="${MNT:-/mnt/ioimg}"

IO_REPO="${IO_REPO:-https://github.com/Lolzen/io-repo/releases/download/current}"
VOID="${VOID:-https://repo-default.voidlinux.org/current}"
INCLUDE="${INCLUDE:-/home/gee/io-packages/iso-include}"

USERNAME="${USERNAME:-deck}"
USERPASS="${USERPASS:-deck}"
ROOTPASS="${ROOTPASS:-deck}"
HOSTNAME="${HOSTNAME:-io}"
TIMEZONE="${TIMEZONE:-Europe/Vienna}"

KERNEL_CMDLINE="loglevel=4 amd_iommu=off audit=0 amdgpu.gttsize=8128 fbcon=rotate:1"

SERVICES="NetworkManager bluetoothd chronyd dbus elogind polkitd seatd sshd udevd jupiter-fan-control io-autologin agetty-tty2 agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6"

[ "$(id -u)" -eq 0 ] || { echo "mkimg: must run as root" >&2; exit 1; }

LOOP=""
MOUNTED=""

cleanup() {
    set +e
    if [ -n "$MOUNTED" ]; then
        umount -R "$MNT" 2>/dev/null
    fi
    if [ -n "$LOOP" ]; then
        losetup -d "$LOOP" 2>/dev/null
    fi
}
trap cleanup EXIT INT TERM

echo "== creating $OUT ($SIZE)"
rm -f "$OUT"
truncate -s "$SIZE" "$OUT"

echo "== partitioning"
# GPT: 512M ESP, rest ext4. sgdisk is scriptable; parted's interactive
# rounding warnings are not.
sgdisk --zap-all "$OUT" > /dev/null
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"IOESP" "$OUT" > /dev/null
sgdisk -n 2:0:0     -t 2:8300 -c 2:"IOROOT" "$OUT" > /dev/null

LOOP=$(losetup --find --show --partscan "$OUT")
echo "   $LOOP"
sleep 1

echo "== formatting"
mkfs.vfat -F32 -n IOESP "${LOOP}p1" > /dev/null
mkfs.ext4 -q -L IOROOT "${LOOP}p2"

echo "== mounting"
mkdir -p "$MNT"
mount "${LOOP}p2" "$MNT"
MOUNTED=1
mkdir -p "$MNT/boot/efi"
mount "${LOOP}p1" "$MNT/boot/efi"

echo "== installing packages"
# -S syncs the index; the Io repo is signed, so the key must be accepted.
XBPS_ARCH=x86_64 xbps-install -S -y -R "$IO_REPO" -R "$VOID" \
    -R "$VOID/nonfree" -R "$VOID/multilib" -R "$VOID/multilib/nonfree" \
    -r "$MNT" io-desktop

#echo "== removing Void's stock kernel"
#chroot "$MNT" xbps-remove -y -f linux
#chroot "$MNT" xbps-remove -y -f linux6.18

echo "== branding"
cp "$INCLUDE/etc/os-release" "$MNT/etc/os-release"

echo "== configuring system"

# fstab by label, so the image does not care which device it lands on.
cat > "$MNT/etc/fstab" << 'EOF'
LABEL=IOROOT  /          ext4  defaults              0 1
LABEL=IOESP   /boot/efi  vfat  defaults,noatime      0 2
tmpfs         /tmp       tmpfs defaults,nosuid,nodev 0 0
EOF

echo "$HOSTNAME" > "$MNT/etc/hostname"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$MNT/etc/localtime"

# Bind the pseudo filesystems so chroot commands behave.
mount --bind /dev "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys "$MNT/sys"
mount --bind /run "$MNT/run"

echo "== creating users"
# Root stays usable for alpha testing. SteamOS locks it; Io does not, yet.
chroot "$MNT" sh -c "echo 'root:$ROOTPASS' | chpasswd"
chroot "$MNT" useradd -m -G wheel,audio,video,input,storage -s /bin/bash "$USERNAME"
chroot "$MNT" sh -c "echo '$USERNAME:$USERPASS' | chpasswd"

# wheel gets sudo, as on any Void install.
echo "%wheel ALL=(ALL:ALL) ALL" > "$MNT/etc/sudoers.d/10-wheel"
chmod 440 "$MNT/etc/sudoers.d/10-wheel"

echo "== enabling services"
for svc in $SERVICES; do
    if [ -d "$MNT/etc/sv/$svc" ]; then
        ln -sf "/etc/sv/$svc" "$MNT/etc/runit/runsvdir/default/"
    else
        echo "   $svc: no such service, skipping"
    fi
done
echo "== removing stock tty1 getty"
rm -f "$MNT/etc/runit/runsvdir/default/agetty-tty1"


echo "== installing bootloader"
# --removable puts the loader at EFI/BOOT/BOOTX64.EFI, which the Deck's
# firmware finds without an NVRAM entry. Without it the image would only
# boot on the machine that built it.
chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=Io --removable --no-nvram || { echo "grub-install failed" >&2; exit 1; }

[ -f "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ] || { echo "no EFI loader written" >&2; exit 1; }

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$KERNEL_CMDLINE\"|" \
    "$MNT/etc/default/grub"
sed -i "s|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR=\"Io\"|" "$MNT/etc/default/grub"

chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg

echo "== generating initramfs"
KVER=$(ls "$MNT/usr/lib/modules" | head -1)
echo "   kernel $KVER"
chroot "$MNT" dracut --force --kver "$KVER" "/boot/initramfs-${KVER}.img"

echo "== finishing"
umount -R "$MNT"
MOUNTED=""
losetup -d "$LOOP"
LOOP=""

echo
echo "built $OUT"
ls -lh "$OUT"
echo
echo "write with:"
echo "  gzip -dc ${OUT}.gz | dd of=/dev/sdX bs=4M status=progress"
echo "or compress first:"
echo "  gzip -1 < $OUT > ${OUT}.gz"
echo
echo "login: $USERNAME / $USERPASS   (root / $ROOTPASS)"
echo "change both on first boot."