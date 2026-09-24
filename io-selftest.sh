#!/bin/sh
# io-selftest - check a running Io system against the expected Alpha 2 state.
#
# Run as root while game mode is running (some checks look at the session):
#   sudo sh io-selftest.sh
#
# Every line is PASS, FAIL or INFO. The checks mirror what was verified by
# hand during Alpha 2, so a fresh image can be compared against a known-good
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
check "kernel.pid_max = 4194304" sh -c '[ "$(sysctl -n kernel.pid_max)" = 4194304 ]'

echo "== packages"
for p in io-desktop io-base io-branding io-session io-steamos-manager linux-neptune-72 deck-hw-support linux-firmware jupiter-fan-control steamos-powerbuttond steamdeck-dsp rnnoise-ladspa holo-zram-swap holo-earlyoom steamos-tuning holo-dmi-rules holo-fstab-repair steamos-passwd xdg-desktop-portal-gamescope rtkit socklog-void kde-plasma; do
    check "installed: $p" xbps-query "$p"
done
for p in io-priv-exec cloud-guest-utils zramen deck-firmware-cirrus linux-neptune io-volumed; do
    check "not installed: $p" sh -c "! xbps-query $p"
done

echo "== services"
for s in dbus elogind NetworkManager io-steamos-manager vpower holo-zram-swap earlyoom socklog-unix nanoklogd; do
    check "service running: $s" sh -c "sv status $s | grep -q '^run:'"
done
check "vpower writes battery metrics" test -s /run/vpower/battery_percent
check "UPower critical action handed to vpower" test -e /etc/UPower/UPower.conf.d/10-holo-defaults.conf
check "no runit polkitd service (D-Bus activated only)" sh -c '[ ! -e /var/service/polkitd ]'
check "exactly one polkitd" sh -c '[ "$(pgrep -c polkitd)" = 1 ]'
check "no resize core service" sh -c '! ls /etc/runit/core-services/ | grep -q resize'

echo "== memory"
check "zram swap active" grep -q '^/dev/zram' /proc/swaps
check "zram uses zstd" sh -c 'zramctl | grep -q zstd'
check "zswap disabled" sh -c 'grep -q N /sys/module/zswap/parameters/enabled'
check "earlyoom runs with Valve arguments" sh -c 'tr "\0" " " < /proc/$(pgrep -x earlyoom)/cmdline | grep -q -- "-S 409600,307200 -r 3600 -n --avoid"'

echo "== game mode session"
check "gamescope running" pgrep -x gamescope-wl
check "gamescope file capability" sh -c 'getcap /usr/bin/gamescope | grep -q cap_sys_nice=ep'
check "gamescope has CAP_SYS_NICE" sh -c 'grep -q "CapEff:.*0000000000800000" /proc/$(pgrep -x gamescope-wl)/status'
check "steam started with -gamepadui" sh -c 'tr "\0" " " < /proc/$(pgrep -o -x steam)/cmdline | grep -q -- -gamepadui'
check "mangoapp running (performance overlay)" pgrep -x mangoapp
check "user in group gamemode" sh -c 'id -nG deck | grep -qw gamemode'
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
check "Steam on the Deck branch" sh -c 'grep -qx steamdeck_stable /home/deck/.local/share/Steam/package/beta'
check "ALSA default device goes through PipeWire" test -e /etc/alsa/conf.d/99-pipewire-default.conf
check "locale en_US.UTF-8 generated" sh -c 'locale -a | grep -qi "^en_US.utf8$"'

echo "== logging"
check "syslog receives daemon messages" test -s /var/log/socklog/daemon/current
check "$U can read syslog (group socklog)" sh -c "id -nG $U | grep -qw socklog"

echo "== desktop"
check "startplasma-wayland present" test -x /usr/bin/startplasma-wayland
check "storage expansion menu entry" test -r /usr/share/applications/io-grow-storage.desktop

echo "== package database"
xbps-pkgdb -a > /tmp/io-selftest-pkgdb.txt 2>&1
N=$(grep -c ERROR /tmp/io-selftest-pkgdb.txt)
info "xbps-pkgdb: $N error line(s), details in /tmp/io-selftest-pkgdb.txt"
info "expected: elogind activation file (removed on purpose), base-files os-release (Io branding)"
grep ERROR /tmp/io-selftest-pkgdb.txt | sed 's/^/      /'

echo
echo "PASS: $PASS  FAIL: $FAIL"