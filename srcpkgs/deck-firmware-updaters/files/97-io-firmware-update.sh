# Io: Valve's firmware updates at boot, before the login manager, as
# SteamOS's jupiter-biosupdate.service and jupiter-controller-update.service
# (both Before=display-manager.service): the BIOS with --auto (only the
# versions Valve marks for automatic updates, at 20 % battery or more, once a
# day at most), then the controller with its update splash. Same time limits
# as Valve's units (90 s, 160 s). A BIOS update restarts the Deck by itself.
# Output goes to /var/log/io-firmware-update.log.
if [ -x /usr/bin/jupiter-biosupdate ] || [ -x /usr/lib/hwsupport/jupiter-controller-update-with-splash ]; then
    {
        echo "== $(date '+%F %T')"
        if [ -x /usr/bin/jupiter-biosupdate ]; then
            timeout 90 /usr/bin/jupiter-biosupdate --auto || echo "jupiter-biosupdate: exit $?"
        fi
        if [ -x /usr/lib/hwsupport/jupiter-controller-update-with-splash ]; then
            timeout 160 /usr/lib/hwsupport/jupiter-controller-update-with-splash || echo "controller update: exit $?"
        fi
    } >> /var/log/io-firmware-update.log 2>&1
fi
