# Io: run Valve's holo-fstab-repair on every boot, as its systemd unit does
# (SteamOS limits that to an fstab changed by the user in the /etc overlay;
# Io's /etc has no overlay, so the check runs whenever fstab exists).
# runit sources core-services, so the script is run as its own process.
if [ -x /usr/lib/steamos/holo-fstab-repair ]; then
	/usr/lib/steamos/holo-fstab-repair
fi
