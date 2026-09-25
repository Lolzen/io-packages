# Io: Valve's 1 GiB swap file in addition to zram (swapfile.service and
# home-swapfile.swap on SteamOS). zram has priority 100, the file the
# default below it, so it only takes over once zram is full. Valve's script
# creates the file if it is missing or broken.
if /usr/libexec/holo-create-swapfile /home/swapfile 1024M; then
    swapon /home/swapfile 2> /dev/null || true
fi
