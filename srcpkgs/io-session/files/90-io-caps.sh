# Io: file capabilities SteamOS's packages carry and Void's cannot (xbps
# packages keep no extended attributes). Setting them on every boot also
# restores them after an update replaced a binary.
#
# gamescope: CAP_SYS_NICE, exactly like on SteamOS (captured: CapPrm/CapEff
# = cap_sys_nice, ambient empty).
# kwin_wayland: CAP_SYS_NICE, as on SteamOS (captured on 3.9.2: getcap
# cap_sys_nice=ep). With it KWin runs its main, output and libinput threads
# at realtime priority (SCHED_RR); without it they are ordinary threads,
# which can lag behind other work.
# Sourced by runit stage 1 - must not exit.
if command -v setcap > /dev/null 2>&1; then
    for bin in /usr/bin/gamescope /usr/bin/kwin_wayland; do
        [ -x "$bin" ] && setcap cap_sys_nice=ep "$bin" 2> /dev/null || true
    done
fi
