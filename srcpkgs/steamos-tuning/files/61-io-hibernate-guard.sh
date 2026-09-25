# Io: hibernation only from the internal NVMe. Hibernating writes RAM plus
# VRAM (about 17 GB on the Deck) to the root filesystem and reads it back on
# resume; on an SD card or a USB stick that takes minutes and wears the
# medium. Anywhere else, elogind is told that hibernation is not allowed, so
# nothing offers it: not Plasma's power menu, not suspend-then-hibernate.
# Written before elogind starts; decided anew at every boot.
io_hibernate_conf=/etc/elogind/sleep.conf.d/10-io-hibernate.conf
case "$(findmnt -no SOURCE /)" in
    /dev/nvme*)
        rm -f "$io_hibernate_conf"
        ;;
    *)
        mkdir -p "${io_hibernate_conf%/*}"
        printf '%s\n' "# Generated at boot by 61-io-hibernate-guard.sh: / is not on the internal NVMe." "[Sleep]" "AllowHibernation=no" "AllowSuspendThenHibernate=no" "AllowHybridSleep=no" > "$io_hibernate_conf"
        ;;
esac
unset io_hibernate_conf
