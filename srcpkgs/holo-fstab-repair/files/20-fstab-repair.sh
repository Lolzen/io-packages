#!/bin/sh
# Disable all lines in fstab where the device is an SD card (/dev/mmcblk*)
# and the mount point is 'none'. These are invalid and prevent UDisks2
# from mounting the cards correctly.
# https://github.com/ValveSoftware/SteamOS/issues/1208
if test -f /etc/fstab && grep -q "^\s*/dev/mmcblk[0-9a-z]*\s\+none\s" /etc/fstab; then
    sed -i '\,^\s*/dev/mmcblk[0-9a-z]*\s\+none\s,{i\
### line disabled by holo-fstab-repair
s/^/#/
}' /etc/fstab
fi
true