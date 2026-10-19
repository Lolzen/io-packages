#!/bin/sh
# io-selftest - check a running Io system against the expected state.
#
# Run as root while game mode is running (some checks look at the session):
#   sudo sh io-selftest.sh
#
# Every line is PASS, FAIL or INFO. The checks mirror what was verified by
# hand during the alphas, so a fresh image can be compared against a known-good
# installation in one go.

U=deck
PASS=0
FAIL=0

ok() { echo "PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }
info() { echo "INFO  $1"; }
check() {
    # check "description" command...
    desc=$1
    shift
    if "$@" > /dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo."
    exit 1
fi

echo "== system"
info "kernel $(uname -r)"
check "kernel 7.2 (linux-neptune-72)" sh -c 'uname -r | grep -q "^7\.2"'
check "Valve's Deck modules in the initramfs (steamos-tuning)" sh -c 'lsinitrd /boot/initramfs-$(uname -r).img | grep -q "steamdeck-hwmon.ko"'
check "Valve's Bluetooth firmware loaded (deck-firmware)" sh -c 'dmesg | grep -q "RTL: fw version 0x3d7679d7"'
check "Valve's VCN firmware loaded (deck-firmware)" sh -c 'dmesg | grep -q "Found VCN firmware Version ENC: 1.27 DEC: 2"'
check "kernel.pid_max = 4194304" sh -c '[ "$(sysctl -n kernel.pid_max)" = 4194304 ]'
# systemd's defaults (50-io-inherited.conf); ufw must not override them
check "rp_filter 2 (loose, as SteamOS)" sh -c '[ "$(sysctl -n net.ipv4.conf.default.rp_filter)" = 2 ]'
check "accept_redirects 1 (ufw's sysctl.conf not applied)" sh -c '[ "$(sysctl -n net.ipv4.conf.default.accept_redirects)" = 1 ]'
check "accept_source_route 0" sh -c '[ "$(sysctl -n net.ipv4.conf.default.accept_source_route)" = 0 ]'
check "ping_group_range 0 2147483647" sh -c 'sysctl -n net.ipv4.ping_group_range | grep -q "^0[[:space:]]*2147483647$"'
check "net.unix.max_dgram_qlen = 512" sh -c '[ "$(sysctl -n net.unix.max_dgram_qlen)" = 512 ]'
check "kwin_wayland file capability (realtime threads)" sh -c 'getcap /usr/bin/kwin_wayland | grep -q cap_sys_nice=ep'

echo "== packages"
# io-desktop pulls in the whole system; a missing dependency shows up in the
# package database check at the end (xbps-pkgdb).
check "installed: io-desktop" xbps-query io-desktop

echo "== services"
for s in dbus elogind NetworkManager io-steamos-manager io-sddm vpower holo-zram-swap earlyoom socklog-unix nanoklogd jupiter-firewall steam-web-debug-portforward gpu-trace wireless-domain-setter; do
    check "service running: $s" sh -c "sv status $s | grep -q '^run:'"
done
check "vpower writes battery metrics" test -s /run/vpower/battery_percent
check "UPower critical action handed to vpower" test -e /etc/UPower/UPower.conf.d/10-holo-defaults.conf
check "exactly one polkitd" sh -c '[ "$(pgrep -c polkitd)" = 1 ]'
check "restart into Io: shutdown hook installed" test -r /etc/runit/shutdown.d/75-io-bootnext.sh
check "restart into Io: io-bootnext finds a boot entry or would create one" sh -c '/usr/libexec/io/io-bootnext --dry-run | grep -q "BootNext"'
check "GRUB boots Io without its menu" sh -c 'grep -q "^GRUB_TIMEOUT=0$" /etc/default/grub && grep -q "set timeout=0" /boot/grub/grub.cfg'
check "Twemoji is the emoji font (ttf-twemoji-default)" sh -c 'fc-match emoji | grep -q "^twemoji.ttf: \"Twemoji\""'
check "requests for Noto Color Emoji get Twemoji" sh -c 'fc-match "Noto Color Emoji" | grep -q "Twemoji"'
check "digits do not fall back to Twemoji" sh -c '! fc-match "sans:charset=30" | grep -q Twemoji'
check "/ has mode 755 (not world-writable)" sh -c '[ "$(stat -c %a /)" = 755 ]'
check "firewall active (ufw)" sh -c 'ufw status | grep -q "Status: active"'
check "bluetoothd with SteamOS's settings" sh -c 'tr "\0" " " < /proc/$(pgrep -x bluetoothd)/cmdline | grep -q /usr/share/io/bluetooth/main.conf'
check "logout ends the session (KillUserProcesses)" grep -q "KillUserProcesses=yes" /etc/elogind/logind.conf.d/10-io-kill-user-processes.conf
check "no iwd service (wpa_supplicant is the default backend)" sh -c '[ ! -e /var/service/iwd ] || grep -q iwd /etc/NetworkManager/conf.d/99-valve-wifi-backend.conf'

echo "== memory"
check "zram swap active" grep -q '^/dev/zram' /proc/swaps
check "zram uses zstd" sh -c 'zramctl | grep -q zstd'
check "zswap disabled" sh -c 'grep -q N /sys/module/zswap/parameters/enabled'
check "swap file active" grep -q '^/home/swapfile' /proc/swaps
if findmnt -no SOURCE / | grep -q '^/dev/nvme'; then
    info "/ on the NVMe: hibernation allowed"
    check "elogind skips the swap size check (hibernation)" sh -c 'tr "\0" "\n" < /proc/$(pgrep -x elogind)/environ | grep -q "^SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1"'
    check "initramfs has io-resume" sh -c 'lsinitrd "/boot/initramfs-$(uname -r).img" | grep -q "pre-mount/09-io-resume.sh"'
else
    check "hibernation blocked (/ not on the NVMe)" grep -q "AllowHibernation=no" /etc/elogind/sleep.conf.d/zz-io-hibernate.conf
fi
check "earlyoom runs with Valve arguments" sh -c 'tr "\0" " " < /proc/$(pgrep -x earlyoom)/cmdline | grep -q -- "-S 409600,307200 -r 3600 -n --avoid"'

echo "== game mode session"
check "SDDM session on seat0" sh -c 'loginctl --no-pager list-sessions | grep -q seat0'
check "gamescope running" pgrep -x gamescope-wl
check "gamescope with stats pipe (-T)" sh -c 'tr "\0" " " < /proc/$(pgrep -x gamescope-wl)/cmdline | grep -q -- " -T "'
check "one io-steamos-manager user half" sh -c '[ "$(pgrep -c -u deck -f "^/usr/bin/python3 /usr/bin/io-steamos-manager$")" = 1 ]'
check "one cecd" sh -c '[ "$(pgrep -c -u deck -x cecd)" = 1 ]'
check "one steam_notif_daemon (notifications to Steam)" sh -c '[ "$(pgrep -c -u deck -f ^/usr/bin/steam_notif_daemon)" = 1 ]'
check "holo portal first in game mode" grep -q "default=holo;gamescope" /usr/share/xdg-desktop-portal/gamescope-portals/gamescope-portals.conf
check "mangoapp has Steam's config file" sh -c 'tr "\0" "\n" < /proc/$(pgrep -x mangoapp)/environ | grep -q ^MANGOHUD_CONFIGFILE='
check "gamescope WSI layer for 32-bit games" test -e /usr/share/vulkan/implicit_layer.d/VkLayer_FROG_gamescope_wsi.x86.json
check "gamescope file capability" sh -c 'getcap /usr/bin/gamescope | grep -q cap_sys_nice=ep'
check "gamescope has CAP_SYS_NICE" sh -c 'grep -q "CapEff:.*0000000000800000" /proc/$(pgrep -x gamescope-wl)/status'
check "steam started with -gamepadui" sh -c 'tr "\0" " " < /proc/$(pgrep -o -x steam)/cmdline | grep -q -- -gamepadui'
check "mangoapp running (performance overlay)" pgrep -x mangoapp
check "mangoapp from Io's overlay (one render per game frame)" sh -c 'xbps-query MangoHud-mangoapp-holo > /dev/null'
check "Mesa from Io's overlay (Valve's patches), 64 and 32 bit" sh -c 'xbps-query mesa-vulkan-radeon-holo > /dev/null && xbps-query mesa-vulkan-radeon-holo-32bit > /dev/null && xbps-query mesa-dri-holo-32bit > /dev/null'
check "Mesa's 32-bit packages stand in for Void's (provides libgbm-32bit)" sh -c 'xbps-query -p provides libgbm-holo-32bit | grep -q "^libgbm-32bit-"'
check "RADV without global BO list for gamescope (Valve's driconf)" grep -q radv_disable_global_bo_list /usr/share/drirc.d/00-radv-defaults.conf
check "deck not in group gamemode (as SteamOS)" sh -c '! id -nG deck | grep -qw gamemode'
check "Steam nice limit 0/28 (Proton nice)" sh -c 'prlimit --nice -o SOFT,HARD --noheadings -p $(pgrep -o -x steam) | grep -q "^ *0 *28 *$"'
check "Steam open-file hard limit 524288" sh -c 'prlimit --nofile -o HARD --noheadings -p $(pgrep -o -x steam) | grep -q "^ *524288 *$"'
check "LIBVA_DRIVER_NAME=radeonsi for Steam" sh -c 'tr "\0" "\n" < /proc/$(pgrep -o -x steam)/environ | grep -q ^LIBVA_DRIVER_NAME=radeonsi'
check "STEAM_USE_WPASUPPLICANT set" sh -c 'tr "\0" "\n" < /proc/$(pgrep -o -x steam)/environ | grep -q ^STEAM_USE_WPASUPPLICANT=1'
check "ibus-daemon running for Steam's keyboard" sh -c 'pgrep -u deck -f "ibus-daemon -r --panel=disable"'
check "IBus engines for Steam's CJK layouts" sh -c 'for c in pinyin table anthy hangul; do [ -e /usr/share/ibus/component/$c.xml ] || exit 1; done; [ -e /usr/share/ibus-table/tables/cangjie5.db ]'
check "STEAM_ENABLE_VOLUME_HANDLER set" sh -c 'tr "\0" "\n" < /proc/$(pgrep -o -x steam)/environ | grep -q ^STEAM_ENABLE_VOLUME_HANDLER=1'
check "STEAM_ENABLE_DYNAMIC_BACKLIGHT set" sh -c 'tr "\0" "\n" < /proc/$(pgrep -o -x steam)/environ | grep -q ^STEAM_ENABLE_DYNAMIC_BACKLIGHT=1'
check "rtkit-daemon running" pgrep -x rtkit-daemon
RAMLOG=/run/user/$(id -u $U)/io-log-gamemode/current
DEVLOG=/home/$U/.local/state/io/log-gamemode/current
check "session log exists (RAM or developer mode)" sh -c "[ -s $RAMLOG ] || [ -s $DEVLOG ]"

echo "== steamos manager"
check "root half running" sh -c 'pgrep -u 0 -f "io-steamos-manager -r"'
check "session half running" sh -c "pgrep -u $U -f io-steamos-manager"
# The fan daemon follows Steam's fan control setting (Settings > System);
# a fresh Steam profile has it off, which stops the service on purpose.
if pgrep -f 'fancontrol.py --run' > /dev/null; then
    info "fan control: OS curve (jupiter-fan-control running)"
else
    info "fan control: firmware (off in Steam's settings, or service stopped)"
fi

echo "== audio"
check "loopback script installed" test -r /usr/share/wireplumber/scripts/io-create-loopback.lua
check "filter chain in its own PipeWire instance" pgrep -f "pipewire -c filter-chain.conf"
check "filter chain memlock 100 MB" sh -c 'prlimit --memlock -o HARD --noheadings -p $(pgrep -f "pipewire -c filter-chain.conf" | head -n 1) | grep -q 104857600'
check "ALSA default device goes through PipeWire" test -e /etc/alsa/conf.d/99-pipewire-default.conf
check "locale en_US.UTF-8 generated" sh -c 'locale -a | grep -qi "^en_US.utf8$"'

echo "== network"
check "Wi-Fi interface is wlan0" test -d /sys/class/net/wlan0
check "wireless regulatory database" test -e /usr/lib/firmware/regulatory.db
info "$(iw reg get 2> /dev/null | grep -m1 country)"

echo "== logging"
check "syslog receives daemon messages" test -s /var/log/socklog/daemon/current
check "$U can read syslog (group socklog)" sh -c "id -nG $U | grep -qw socklog"

echo "== desktop"
check "startplasma-wayland present" test -x /usr/bin/startplasma-wayland
check "storage expansion menu entry" test -r /usr/share/applications/io-grow-storage.desktop

echo "== firmware (check modes only, nothing is flashed)"
check "BIOS updater installed (deck-firmware-updaters)" test -x /usr/bin/jupiter-biosupdate
check "controller updater installed (deck-firmware-updaters)" test -x /usr/bin/jupiter-controller-update
check "dock updater installed (jupiter-dock-updater-bin)" test -x /usr/lib/jupiter-dock-updater/jupiter-dock-updater.sh
BIOSOUT=$(/usr/bin/jupiter-biosupdate check 2>&1)
BIOSRC=$?
info "jupiter-biosupdate check: exit $BIOSRC (0 = nothing to do, 7 = update available): $(echo "$BIOSOUT" | tr '\n' ' ' | cut -c1-160)"
check "BIOS check runs (exit 0 or 7)" sh -c "[ $BIOSRC = 0 ] || [ $BIOSRC = 7 ]"
CTRLOUT=$(/usr/bin/jupiter-controller-update --check 2> /dev/null)
info "controller: $(echo "$CTRLOUT" | tr '\n' ' ')"
case "$CTRLOUT" in *needs_update=*) CTRLOK=yes ;; *) CTRLOK=no ;; esac
check "controller check runs" test "$CTRLOK" = yes
info "last firmware run at boot: $(grep '^==' /var/log/io-firmware-update.log 2> /dev/null | tail -n 1)"

echo "== factory reset (nothing is reset)"
check "io-factory-reset installed" test -x /usr/bin/io-factory-reset
check "no factory reset pending" sh -c '/usr/bin/io-factory-reset --status | grep -q "no reset pending"'
if [ -s /var/lib/io/factory-defaults ]; then
    info "image settings for a reset: /var/lib/io/factory-defaults"
else
    info "no /var/lib/io/factory-defaults (image older than io-factory-reset): a reset uses the build defaults"
fi

echo "== storage"
HW=/usr/lib/hwsupport
RULES=/usr/lib/udev/rules.d
ROOTDISK=$($HW/io-root-disk)
info "Io runs from: ${ROOTDISK:-unknown}"
check "root disk can be worked out" test -n "$ROOTDISK"
# Only rule lines count: the file's comment names systemd-run too.
check "automount rule active (no systemd-run)" sh -c "! grep -v '^#' $RULES/99-steamos-automount.rules | grep -q systemd-run && grep -q '^ACTION==.add' $RULES/99-steamos-automount.rules"
check "automount detached from udev (io-detach)" sh -c "test -x $HW/io-detach && grep -q io-detach $RULES/99-steamos-automount.rules"
check "udisks2 installed" xbps-query udisks2
check "Steam may eject and adopt drives (game mode)" grep -q "^export STEAM_ALLOW_DRIVE_ADOPT=1" /usr/bin/io-gamemode
check "format-device.sh refuses the system disk" grep -q "Io runs from" $HW/format-device.sh
case "$ROOTDISK" in
    nvme*) info "Io runs from the NVMe: internal SSD not hidden" ;;
    *)
        if [ -e /dev/nvme0n1 ]; then
            check "internal SSD hidden from udisks" sh -c "udevadm info /dev/nvme0n1 | grep -q UDISKS_IGNORE=1"
        else
            info "no internal NVMe SSD"
        fi
        ;;
esac
SM=com.steampowered.SteamOSManager1
SMP=/com/steampowered/SteamOSManager1
check "root half: storage jobs (JobManager1)" sh -c "busctl introspect $SM $SMP/Jobs | grep -q JobManager1"
check "root half: Atomupd1 (system updates)" sh -c "busctl get-property com.steampowered.Atomupd1 /com/steampowered/Atomupd1 com.steampowered.Atomupd1 Version | grep -q 'u 8'"
check "steamos-update speaks Steam's interface" /usr/bin/steamos-update --supports-duplicate-detection
SPID=$(pgrep -o -x steam)
if [ -n "$SPID" ]; then
    SBUS=$(tr '\0' '\n' < /proc/$SPID/environ | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)
    check "session half: Storage1 for Steam" sh -c "setpriv --reuid $(id -u $U) --regid $(id -g $U) --init-groups env 'DBUS_SESSION_BUS_ADDRESS=$SBUS' busctl --user introspect $SM $SMP | grep -q Storage1"
    check "session half: UdevEvents1 (USB over-current)" sh -c "setpriv --reuid $(id -u $U) --regid $(id -g $U) --init-groups env 'DBUS_SESSION_BUS_ADDRESS=$SBUS' busctl --user introspect $SM $SMP | grep -q UdevEvents1"
    check "session half: FactoryReset1 (io-factory-reset)" sh -c "setpriv --reuid $(id -u $U) --regid $(id -g $U) --init-groups env 'DBUS_SESSION_BUS_ADDRESS=$SBUS' busctl --user introspect $SM $SMP | grep -q FactoryReset1"
else
    info "Steam not running: Storage1, UdevEvents1 not checked"
fi

echo "== package database"
xbps-pkgdb -a > /tmp/io-selftest-pkgdb.txt 2>&1
N=$(grep -c ERROR /tmp/io-selftest-pkgdb.txt)
info "xbps-pkgdb: $N error line(s), details in /tmp/io-selftest-pkgdb.txt"
info "expected: elogind activation file (removed on purpose), base-files os-release and lsb_release (Io branding)"
grep ERROR /tmp/io-selftest-pkgdb.txt | sed 's/^/      /'

echo
echo "PASS: $PASS  FAIL: $FAIL"