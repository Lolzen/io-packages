# Io: hibernation only from the internal NVMe. Hibernating writes RAM plus
# VRAM (about 17 GB on the Deck) to a swap file in /home and reads it back on
# resume; on an SD card or a USB stick that takes minutes and wears the
# medium. On the NVMe, Valve's suspend-then-hibernate of SteamOS 3.9.2 holds
# (steamos-suspend-then-hibernate.conf): the swap file is created when
# hibernating, the initramfs finds the image through an EFI variable (sleep
# hook io-hibernate, dracut module io-resume). Elsewhere elogind is told
# that hibernation is not allowed, so nothing offers it: not Steam, not
# Plasma's power menu, not suspend-then-hibernate. Written before elogind
# starts; decided anew at every boot. The file name sorts after Valve's
# steamos-suspend-then-hibernate.conf, so it wins over it.
io_hibernate_conf=/etc/elogind/sleep.conf.d/zz-io-hibernate.conf
# name used up to steamos-tuning 1.4 (sorted before Valve's file)
rm -f /etc/elogind/sleep.conf.d/10-io-hibernate.conf
io_hibernate_ok=no
case "$(findmnt -no SOURCE /)" in
    /dev/nvme*)
        [ -d /sys/firmware/efi ] && io_hibernate_ok=yes
        ;;
esac
if [ "$io_hibernate_ok" = yes ]; then
    rm -f "$io_hibernate_conf"
else
    mkdir -p "${io_hibernate_conf%/*}"
    printf '%s\n' "# Generated at boot by 61-io-hibernate-guard.sh: / is not on the internal NVMe (or no UEFI boot)." "[Sleep]" "AllowHibernation=no" "AllowSuspendThenHibernate=no" "AllowHybridSleep=no" > "$io_hibernate_conf"
fi
unset io_hibernate_conf io_hibernate_ok
