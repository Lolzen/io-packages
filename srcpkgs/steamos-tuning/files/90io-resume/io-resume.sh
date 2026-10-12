#!/bin/sh
# io-resume (dracut pre-mount hook, before root is mounted): if Io's sleep
# hook left the image location in the EFI variable IoHibernateLocation
# ("UUID=<filesystem> OFFSET=<pages>"), delete the variable and hand the
# location to the kernel, which restores the image at once. Without an image
# there (a resume already done, or the swap file was overwritten) the kernel
# finds no hibernation signature and the boot goes on. The variable is
# deleted first, so a broken image is tried once, not at every boot.
# Sourced by dracut: no exit.

io_resume() {
    local efivars=/sys/firmware/efi/efivars
    local var="$efivars/IoHibernateLocation-00693127-9e1a-4740-b3c3-13fdd5f0df56"
    local data uuid offset dev n

    [ -d /sys/firmware/efi ] || return 0
    if ! mountpoint -q "$efivars" 2> /dev/null; then
        mount -t efivarfs efivarfs "$efivars" 2> /dev/null || return 0
    fi
    [ -e "$var" ] || return 0

    # 4 bytes of attributes, then the value
    data=$(tail -c +5 "$var" 2> /dev/null)
    chattr -i "$var" 2> /dev/null
    rm -f "$var"

    uuid=$(echo "$data" | sed -n 's/.*UUID=\([^ ]*\).*/\1/p')
    offset=$(echo "$data" | sed -n 's/.*OFFSET=\([0-9]*\).*/\1/p')
    [ -n "$uuid" ] || return 0

    # The filesystem with the swap file: on Io's NVMe installation the root
    # filesystem, which the initramfs has found before this hook.
    n=0
    while [ ! -e "/dev/disk/by-uuid/$uuid" ] && [ $n -lt 50 ]; do
        sleep 0.1
        n=$((n + 1))
    done
    dev=$(readlink -f "/dev/disk/by-uuid/$uuid" 2> /dev/null)
    [ -b "$dev" ] || { warn "io-resume: no device with UUID $uuid"; return 0; }

    info "io-resume: resuming from $dev, offset ${offset:-0}"
    echo "${offset:-0}" > /sys/power/resume_offset
    # the kernel restores the image here, if there is one
    echo "$(cat "/sys/class/block/${dev##*/}/dev")" > /sys/power/resume
    info "io-resume: no hibernation image on $dev, booting normally"
    # Cleared again: elogind refuses to hibernate while /sys/power/resume
    # names a swap that is not active.
    echo 0 > /sys/power/resume_offset
    echo 0:0 > /sys/power/resume
    return 0
}

io_resume
unset -f io_resume
