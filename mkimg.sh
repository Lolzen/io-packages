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
#
# Paths below are hardcoded to /home/gee instead of $HOME: sudo replaces
# $HOME with /root, which silently sends the image and the branding files
# to the wrong place.

set -eu

OUT="${OUT:-/home/gee/io.img}"
SIZE="${SIZE:-12G}"
MNT="${MNT:-/mnt/ioimg}"
INCLUDE="${INCLUDE:-/home/gee/io-packages/iso-include}"

IO_REPO="${IO_REPO:-https://github.com/Lolzen/io-repo/releases/download/current}"
VOID="${VOID:-https://repo-default.voidlinux.org/current}"

USERNAME="${USERNAME:-deck}"
USERPASS="${USERPASS:-deck}"
ROOTPASS="${ROOTPASS:-deck}"
HOSTNAME="${HOSTNAME:-io}"
TIMEZONE="${TIMEZONE:-Europe/Vienna}"

KERNEL_CMDLINE="loglevel=4 amd_iommu=off audit=0 amdgpu.gttsize=8128 fbcon=rotate:1"

SERVICES="NetworkManager bluetoothd chronyd dbus polkitd seatd sshd udevd jupiter-fan-control io-autologin agetty-tty2 agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6"

# Hashed on the host, not inside the chroot: chpasswd's internal crypt()
# call silently failed to write root's entry there before (the shadow line
# ended up with the literal string "x" instead of a hash). openssl's own
# implementation does not depend on the target rootfs's crypt support.
ROOTHASH=$(openssl passwd -6 "$ROOTPASS")
USERHASH=$(openssl passwd -6 "$USERPASS")

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
XBPS_ARCH=x86_64 xbps-install -S -y -R "$IO_REPO" -R "$VOID" -R "$VOID/nonfree" -R "$VOID/multilib" -R "$VOID/multilib/nonfree" -r "$MNT" io-desktop

echo "== branding"
# mkimg does not go through mklive's -I option, so this has to be copied by
# hand. Without it the image boots with Void's stock os-release.
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
# usermod -p writes the hash as-is instead of hashing plaintext inside the
# chroot, so it does not depend on the target's crypt() working correctly.
chroot "$MNT" usermod -p "$ROOTHASH" root
chroot "$MNT" useradd -m -G wheel,audio,video,input,storage -s /bin/bash "$USERNAME"
chroot "$MNT" usermod -p "$USERHASH" "$USERNAME"

# wheel gets sudo, as on any Void install.
echo "%wheel ALL=(ALL:ALL) ALL" > "$MNT/etc/sudoers.d/10-wheel"
chmod 440 "$MNT/etc/sudoers.d/10-wheel"

echo "== verifying passwords"
# chpasswd has failed silently before (image booted, but nobody could log
# in through anything that actually checks the password, like tty2's
# plain login - only io-autologin's --autologin worked, because that
# skips authentication entirely). Catch that here instead of at the
# console.
for u in root "$USERNAME"; do
    HASH=$(chroot "$MNT" awk -F: -v u="$u" '$1 == u { print $2 }' /etc/shadow)
    case "$HASH" in
        \$*) ;;
        *) echo "mkimg: $u has no valid password hash (got: '$HASH')" >&2; exit 1 ;;
    esac
done

echo "== enabling services"
for svc in $SERVICES; do
    if [ -d "$MNT/etc/sv/$svc" ]; then
        ln -sf "/etc/sv/$svc" "$MNT/etc/runit/runsvdir/default/"
    else
        echo "   $svc: no such service, skipping"
    fi
done

rm -f "$MNT/usr/share/dbus-1/system-services/org.freedesktop.login1.service"

# Void's base-system post-install trigger enables agetty-tty1 by default,
# regardless of what is in SERVICES above. io-autologin owns tty1 instead,
# and the two fight over it if both are linked.
rm -f "$MNT/etc/runit/runsvdir/default/agetty-tty1"

echo "== installing bootloader"
# --removable puts the loader at EFI/BOOT/BOOTX64.EFI, which the Deck's
# firmware finds without an NVRAM entry. Without it the image would only
# boot on the machine that built it.
chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Io --removable --no-nvram
[ -f "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ] || { echo "mkimg: no EFI loader written" >&2; exit 1; }

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$KERNEL_CMDLINE\"|" "$MNT/etc/default/grub"
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
chown gee:gee "$OUT"

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