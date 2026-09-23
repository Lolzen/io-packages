#!/bin/sh
# io-boottime - seconds after kernel start at which each boot stage began.
# Run with sudo right after a cold boot, before switching sessions.
UP=$(cut -d. -f1 /proc/uptime)
show() {
    if [ -z "$2" ]; then
        printf "%-24s -\n" "$1"
        return
    fi
    E=$(ps -o etimes= -p "$2" | tr -d ' ')
    printf "%-24s %4ss\n" "$1" $((UP - E))
}
echo "== kernel"
dmesg | grep -m1 "Run /init"
dmesg | grep -m1 "Switching root"
echo "== system"
show "runsvdir" "$(pgrep -o -x runsvdir)"
show "dbus (system)" "$(pgrep -o -f 'dbus-daemon --system')"
show "NetworkManager" "$(pgrep -o -x NetworkManager)"
show "io-steamos-manager -r" "$(pgrep -o -f 'io-steamos-manager -r')"
echo "== session"
show "login shell (deck)" "$(pgrep -o -u deck -x bash)"
show "dbus-run-session" "$(pgrep -o -f '^dbus-run-session')"
show "pipewire" "$(pgrep -o -x pipewire)"
show "gamescope" "$(pgrep -o -x gamescope-wl)"
show "steam" "$(pgrep -o -x steam)"
show "steamwebhelper" "$(pgrep -o -f steamwebhelper)"