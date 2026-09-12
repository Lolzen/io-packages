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

SERVICES="NetworkManager bluetoothd chronyd dbus elogind polkitd seatd sshd udevd jupiter-fan-control io-autologin agetty-tty2 agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6"

# Belongs logically in io-desktop's own depends (same reasoning as every
# other package on this list), but installed explicitly here too so a
# build never silently ships without it even if the template falls out of
# sync. Without these, the running system has no persistent
# /etc/xbps.d/ entry for nonfree/multilib - the -R flags below only grant
# access for this one install call, not for anything done on-device later.
EXTRA_PACKAGES="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree cloud-guest-utils"

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

# Grows the root partition and its ext4 filesystem to fill whatever card
# the image ends up on (64G, 128G, ...) instead of staying stuck at $SIZE.
# cloud-guest-utils ships this as a runit core-service, so it just runs on
# every boot; a partition that's already full-size is a cheap no-op.
sed -i 's/^#ENABLE_ROOT_GROWPART=yes/ENABLE_ROOT_GROWPART=yes/' "$MNT/etc/default/growpart"

echo "== network check script"
# Build-injected, not a package: Steam needs a real connection on first
# boot / after updates, and unlike the ethernet-only wait this also
# handles pure-WiFi setups and dock-provided ethernet. Kept separate from
# io-session on purpose - if proper offline bootstrapping ever works, this
# whole step can just be dropped again without a package release.
mkdir -p "$MNT/usr/local/bin"
cat > "$MNT/usr/local/bin/io-netcheck" << 'EOF'
#!/bin/sh
# io-netcheck - ensure a network connection exists before continuing.
# Build-injected by mkimg.sh, not part of any package.
#
# Runs on every tty1 login, and a crashed/restarted session produces a
# fresh login each time - so this checks a /run flag first and skips
# straight through once resolved for this boot, instead of re-prompting
# on every single restart.

FLAG=/run/io-netcheck.done

[ -f "$FLAG" ] && exit 0

# NetworkManager may still be starting up right after boot; wait briefly
# for it to actually be running before trusting its answer, rather than
# reading "not ready yet" as "no network".
i=0
while ! sv status NetworkManager 2>/dev/null | grep -q "^run:" && [ $i -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done

has_ethernet() {
    nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q "^ethernet:connected"
}

has_wifi() {
    nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q "^wifi:connected"
}

connected() {
    has_ethernet || has_wifi
}

if connected; then
    touch "$FLAG"
    exit 0
fi

while ! connected; do
    clear
    echo "== Netzwerk =="
    echo
    echo "Es wurde weder eine Ethernet- noch eine WLAN-Verbindung gefunden."
    echo "Bitte verbinde dich, um fortzufahren."
    echo
    echo "  1) Ethernet (z.B. per Dock)"
    echo "  2) WLAN"
    echo "  3) Ohne Verbindung fortfahren"
    echo
    printf "Auswahl [1/2/3]: "
    read choice

    case "$choice" in
        1)
            echo
            echo "Kabel/Dock anschliessen. Warte auf Verbindung (30s)..."
            i=0
            while ! has_ethernet && [ $i -lt 30 ]; do
                sleep 1
                i=$((i + 1))
            done
            if has_ethernet; then
                echo "Ethernet verbunden."
                sleep 1
            else
                echo "Keine Ethernet-Verbindung erkannt."
                sleep 2
            fi
            ;;
        2)
            echo
            echo "Suche WLAN-Netzwerke..."
            nmcli device wifi rescan >/dev/null 2>&1
            sleep 2
            nmcli -f SSID,SIGNAL,SECURITY device wifi list
            echo
            printf "SSID: "
            read ssid
            printf "Passwort: "
            stty -echo
            read pass
            stty echo
            echo
            nmcli device wifi connect "$ssid" password "$pass"
            sleep 2
            ;;
        3)
            echo "Fahre ohne Netzwerkverbindung fort."
            sleep 1
            break
            ;;
        *)
            echo "Ungueltige Auswahl."
            sleep 1
            ;;
    esac
done

touch "$FLAG"
exit 0
EOF
chmod 755 "$MNT/usr/local/bin/io-netcheck"

# Hook it in right before the very first io-start on tty1, patched onto the
# installed profile.d script rather than the io-session package itself -
# this line goes away cleanly if proper offline bootstrapping ever removes
# the need for it, no package release required either way.
sed -i '/\/dev\/tty1/a\    [ -x /usr/local/bin/io-netcheck ] && /usr/local/bin/io-netcheck' "$MNT/etc/profile.d/io-session.sh"

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
# _seatd is required for libseat to grant socket access - without it
# gamescope falls back to a permission error on /run/seatd.sock.
chroot "$MNT" usermod -p "$ROOTHASH" root
chroot "$MNT" useradd -m -G wheel,audio,video,input,storage,_seatd -s /bin/bash "$USERNAME"
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