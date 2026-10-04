# Io: gamescope runs with CAP_SYS_NICE as a file capability, exactly like
# on SteamOS (captured: CapPrm/CapEff = cap_sys_nice, ambient empty).
# gamescope comes from Void's package, so an update replaces the binary and
# drops the capability; setting it on every boot restores it.
# Sourced by runit stage 1 - must not exit.
if [ -x /usr/bin/gamescope ] && command -v setcap > /dev/null 2>&1; then
    setcap cap_sys_nice=ep /usr/bin/gamescope 2> /dev/null || true
fi