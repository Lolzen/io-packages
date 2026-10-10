# Io: Restart starts Io again, not the firmware's default system (see
# /usr/libexec/io/io-bootnext). Only on reboot: runit marks it by making
# /run/runit/reboot executable (test -x fails on a noexec mount, hence
# find, as Void's 90-kexec.sh does). Before 80-filesystems.sh, which
# unmounts efivarfs.
#
# Sourced by /etc/runit/3 - must not exit.
if [ -z "${IS_CONTAINER:-}" ] && [ -n "$(find /run/runit/reboot -perm -u+x 2> /dev/null)" ]; then
    [ -x /usr/libexec/io/io-bootnext ] && /usr/libexec/io/io-bootnext
fi
