# Io: a pending factory reset (io-factory-reset --prepare user or all, asked
# for by Steam) erases the user data here, before any service starts and
# while nothing uses /home: SteamOS's initramfs formats its /home and /var
# partitions at the same point. If it does not finish, the request stays
# and the next start tries again, as on SteamOS.
# Sourced by /etc/runit/1, after the filesystems are mounted read-write.
if [ -x /usr/bin/io-factory-reset ] && [ -f /var/lib/io/factory-reset/request ]; then
    msg "Factory reset: erasing user data..."
    if ! IO_FACTORY_RESET_AT_BOOT=1 /usr/bin/io-factory-reset --apply; then
        msg_warn "Factory reset incomplete; tried again at the next start (/var/log/io-factory-reset.log)"
    fi
fi
