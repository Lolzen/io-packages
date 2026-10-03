# Io: hibernation only from the internal NVMe, and only once resuming is set
# up. Hibernating writes RAM plus VRAM (about 17 GB on the Deck) to the root
# filesystem and reads it back on resume; on an SD card or a USB stick that
# takes minutes and wears the medium. And without a resume= on the kernel
# command line nothing reads the image back: the session would be lost as
# if the power had been cut. Valve's resume path (the swap file's position
# in an EFI variable, through systemd) is not ported yet, so on an NVMe
# installation hibernation stays off until resume= is set by hand or by a
# later Io release. Otherwise elogind is told that hibernation is not
# allowed, so nothing offers it: not Plasma's power menu, not
# suspend-then-hibernate. Written before elogind starts; decided anew at
# every boot.
io_hibernate_conf=/etc/elogind/sleep.conf.d/10-io-hibernate.conf
io_hibernate_ok=no
case "$(findmnt -no SOURCE /)" in
    /dev/nvme*)
        case " $(cat /proc/cmdline) " in
            *" resume="*) io_hibernate_ok=yes ;;
        esac
        ;;
esac
if [ "$io_hibernate_ok" = yes ]; then
    rm -f "$io_hibernate_conf"
else
    mkdir -p "${io_hibernate_conf%/*}"
    printf '%s\n' "# Generated at boot by 61-io-hibernate-guard.sh: / is not on the internal NVMe, or no resume= on the kernel command line." "[Sleep]" "AllowHibernation=no" "AllowSuspendThenHibernate=no" "AllowHybridSleep=no" > "$io_hibernate_conf"
fi
unset io_hibernate_conf io_hibernate_ok
