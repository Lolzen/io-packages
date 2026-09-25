# Io: Valve's CFS scheduler tunings (holo-cfs-debugfs-tunings.service on
# SteamOS). systemd mounts debugfs on its own; runit does not, so mount it
# first. Valve's script skips values the kernel no longer offers: with the
# EEVDF scheduler only nr_migrate and migration_cost_ns are left.
if ! mountpoint -q /sys/kernel/debug; then
    mount -t debugfs debugfs /sys/kernel/debug 2> /dev/null
fi
/usr/libexec/holo-cfs-debugfs-settings || true
