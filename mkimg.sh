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
#   sudo SIZE=24G ./mkimg.sh        larger image
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
SIZE="${SIZE:-16G}"
MNT="${MNT:-/mnt/ioimg}"
INCLUDE="${INCLUDE:-/home/gee/io-packages/iso-include}"

IO_REPO="${IO_REPO:-https://github.com/Lolzen/io-repo/releases/download/current}"
VOID="${VOID:-https://repo-default.voidlinux.org/current}"

USERNAME="${USERNAME:-deck}"
USERPASS="${USERPASS:-deck}"
ROOTPASS="${ROOTPASS:-deck}"
HOSTNAME="${HOSTNAME:-io}"
TIMEZONE="${TIMEZONE:-Europe/Vienna}"
LANG_DEFAULT="${LANG_DEFAULT:-en_US.UTF-8}"
# The locales SteamOS ships precompiled (holo-glibc-locales): every
# language and region Steam offers. Generated from Void's glibc-locales.
IO_LOCALES="bg_BG cs_CZ da_DK de_AT de_BE de_CH de_DE de_IT de_LI de_LU
 el_CY el_GR en_AG en_AU en_BW en_CA en_DK en_GB en_HK en_IE en_IL en_IN
 en_NG en_NZ en_PH en_SC en_SG en_US en_ZA en_ZM en_ZW es_AR es_BO es_CL
 es_CO es_CR es_CU es_DO es_EC es_ES es_GT es_HN es_MX es_NI es_PA es_PE
 es_PR es_PY es_SV es_US es_UY es_VE fi_FI fr_BE fr_CA fr_CH fr_FR fr_LU
 hu_HU it_CH it_IT ja_JP ko_KR nb_NO nl_AW nl_BE nl_NL pl_PL pt_BR pt_PT
 ro_RO ru_RU ru_UA sv_FI sv_SE th_TH tr_CY tr_TR uk_UA vi_VN zh_CN zh_HK
 zh_SG zh_TW"

# Kernel command line as on SteamOS 3.8.4 (captured), minus what is
# systemd-, A/B- or SteamOS-specific (rd.systemd.gpt_auto, fsck.*,
# steamos.efi) and with two Io differences: fbcon=rotate:1 instead of
# fbcon=vc:4-6 (tty1 keeps a readable console for the fallback shell), and
# no console=tty1. amdgpu.gttsize is gone: SteamOS sizes GTT through
# ttm.pages_min instead.
KCMD_LOG="log_buf_len=4M loglevel=3 quiet splash plymouth.ignore-serial-consoles"
KCMD_GPU1="amd_iommu=off amdgpu.lockup_timeout=5000,10000,10000,5000"
KCMD_GPU2="ttm.pages_min=2097152 amdgpu.sched_hw_submission=4 amdgpu.dcdebugmask=0x20000"
KCMD_MISC="audit=0 rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 fbcon=rotate:1"
KERNEL_CMDLINE="$KCMD_LOG $KCMD_GPU1 $KCMD_GPU2 $KCMD_MISC"

SERVICES="NetworkManager bluetoothd chronyd dbus earlyoom elogind iio-sensor-proxy sshd udevd socklog-unix nanoklogd holo-zram-swap jupiter-fan-control io-steamos-manager io-autologin agetty-tty2 agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6"

# Belongs logically in io-desktop's own depends (same reasoning as every
# other package on this list), but installed explicitly here too so a
# build never silently ships without it even if the template falls out of
# sync. Without these, the running system has no persistent
# /etc/xbps.d/ entry for nonfree/multilib - the -R flags below only grant
# access for this one install call, not for anything done on-device later.
EXTRA_PACKAGES="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

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
XBPS_ARCH=x86_64 xbps-install -S -y -R "$IO_REPO" -R "$VOID" -R "$VOID/nonfree" -R "$VOID/multilib" -R "$VOID/multilib/nonfree" -r "$MNT" io-desktop $EXTRA_PACKAGES

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

# Locales as on SteamOS: only LANG in locale.conf (Void's default also sets
# LC_COLLATE=C), and the UTF-8 locales of every language Steam offers.
# glibc-locales generates them from libc-locales when it is reconfigured
# below.
printf 'LANG=%s\n' "$LANG_DEFAULT" > "$MNT/etc/locale.conf"
for loc in $IO_LOCALES; do
    sed -i -E "s/^#[[:space:]]*(${loc}(\.UTF-8)? UTF-8)[[:space:]]*$/\1/" "$MNT/etc/default/libc-locales"
done

# Bind the pseudo filesystems so chroot commands behave.
mount --bind /dev "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys "$MNT/sys"
mount --bind /run "$MNT/run"

echo "== reconfiguring packages"
# xbps-install above ran before /proc et al. were bind-mounted, so any
# package with a post_install/trigger script (io-session's PipeWire
# symlink hook, among possibly others) got left unpacked but never
# configured - xbps silently defers that without a working chroot. Redo
# it now that the binds are in place.
chroot "$MNT" xbps-reconfigure -a
# Force it for glibc-locales: it may already count as configured from the
# install step, and only its configure step generates the locales enabled
# above.
chroot "$MNT" xbps-reconfigure -f glibc-locales

echo "== creating users"
# Root stays usable for alpha testing. SteamOS locks it; Io does not, yet.
# usermod -p writes the hash as-is instead of hashing plaintext inside the
# chroot, so it does not depend on the target's crypt() working correctly.
# _seatd is required for libseat to grant socket access - without it
# gamescope falls back to a permission error on /run/seatd.sock.
chroot "$MNT" usermod -p "$ROOTHASH" root
chroot "$MNT" useradd -m -G wheel,audio,video,input,storage,socklog -s /bin/bash "$USERNAME"
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
# Waits briefly for each service directory instead of skipping on the first
# miss - seen jupiter-fan-control and elogind both get skipped once despite
# being correctly listed here and present under /etc/sv/, cause still not
# fully understood. The wait is cheap insurance either way.
for svc in $SERVICES; do
    i=0
    while [ ! -d "$MNT/etc/sv/$svc" ] && [ $i -lt 5 ]; do
        sleep 1
        i=$((i + 1))
    done
    if [ -d "$MNT/etc/sv/$svc" ]; then
        ln -sf "/etc/sv/$svc" "$MNT/etc/runit/runsvdir/default/"
    else
        echo "   $svc: no such service after waiting, skipping" >&2
    fi
done

# Void's base-system post-install trigger enables agetty-tty1 by default,
# regardless of what is in SERVICES above. io-autologin owns tty1 instead,
# and the two fight over it if both are linked.
rm -f "$MNT/etc/runit/runsvdir/default/agetty-tty1"

# elogind ships both the runit service above and a dbus activation file.
# Whichever loses the boot race retries every second forever. Removing the
# activation file leaves the runit service as the only way elogind starts.
rm -f "$MNT/usr/share/dbus-1/system-services/org.freedesktop.login1.service"

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