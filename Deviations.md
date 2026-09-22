# Deviations from SteamOS

Reference: SteamOS 3.8.4 on the same Steam Deck LCD, captured in September
2026 (process environments and capabilities, SteamOS Manager D-Bus values
and calls, sysfs, systemd units, configuration files). Everything not listed
here is meant to behave as on SteamOS; a difference that is not on this page
is a bug.

---

## Design choices

| Io | SteamOS | Why |
|---|---|---|
| Void Linux with runit | Arch Linux with systemd | The point of the project |
| Writable root file system, software through xbps | Read-only root, A/B images, atomic updates | Simpler, and lets users install anything from Void's repositories. A/B updates are a possible post-1.0 goal |
| No Flatpak, no Discover; OctoXBPS as graphical package manager | Flatpak through Discover | SteamOS needs Flatpak because its root is read-only. Io does not; Flatpak can still be installed by hand |
| Steam Deck LCD (Jupiter) only | LCD and OLED (Galileo) | No OLED hardware to test with |
| Disk image written with `dd` | Recovery image with installer | Fixed hardware, nothing for an installer to ask. The live ISO route is blocked by a dracut/void-mklive incompatibility |
| Io-branded boot splash and update screen | SteamOS logo | Valve's logos are Valve's trademarks; Io does not ship them |
| Io's own messages are English only, not localized | Localized | One-person project; English as the common denominator |
| SSH server enabled out of the box, user `deck` with password `deck` | SSH off; enabled through Steam's developer settings, no password until the user sets one | Needed during the test phase. Images for 1.0 will follow SteamOS |

---

## Login and sessions

- **No display manager.** `agetty` logs `deck` in automatically on tty1,
  `/etc/profile.d/io-session.sh` runs `io-start`, which starts either game
  mode or Plasma under its own D-Bus session bus. SteamOS uses SDDM and
  systemd user units. Switching to SDDM is a candidate for a later
  milestone.
- **gamescope starts Steam as its child.** SteamOS runs gamescope and Steam
  as two systemd units and passes the display names through a startup socket
  (`-R`); Io does not need it. The statistics pipe (`-T`) is left out too,
  it only feeds mangoapp.
- **Steam launch flags, gamescope arguments and environment match
  SteamOS**, except variables whose counterpart Io does not have yet
  (mangoapp, HDMI-CEC daemon, status LED, storage helpers, systemd scopes,
  Steam input method modules, Steam's own volume handler). Setting them
  would show controls in Steam that do nothing.
- **tty1 keeps its text console.** SteamOS moves the console to tty4–6
  (`fbcon=vc:4-6`). Io keeps it on tty1 because that is where the fallback
  shell and the last log lines appear when a session dies.
- **Session output goes to a rotating log** (`/run/user/1000/io-log-<session>/`,
  or `~/.local/state/io/` while Steam's developer mode is on) instead of
  the systemd journal.
- **GPU reset handling:** where Valve's udev rule restarts SDDM after a GPU
  crash, Io ends gamescope and the session restarts through
  `io-session.sh`.

---

## SteamOS Manager

`io-steamos-manager` is Io's own Python implementation of
`com.steampowered.SteamOSManager1`. Valve's Rust daemon depends on systemd
throughout. The structure is the same as Valve's: a root half on the system
bus (runit service) that does all privileged work, and a session half on
the session bus that Steam talks to.

- **Access to the root half** is limited to root and the `wheel` group.
  Valve allows any local user.
- **Values match SteamOS** (TDP 3–15 W, GPU power profiles `CAPPED` and
  `UNCAPPED`, desktop session `plasma.desktop`).
- **Not implemented**, for lack of a counterpart on Io: `Storage1`, `Jobs`,
  `UdevEvents1`, `LowPowerMode1`, `HdmiCec1`, `Audio1`, `ScreenReader0/1`,
  `UpdateBios1`, `UpdateDock1`, `FactoryReset1`, `WifiDebug1`.
- **`CpuScheduler1`** offers only `none`; SteamOS also offers `lavd`, which
  needs `scx_scheds`.
- **Wi-Fi backend:** Io uses wpa_supplicant and reports it; switching is not
  implemented. SteamOS defaults to iwd. Decision pending.

---

## System services

- **elogind** instead of systemd-logind; **polkit** is started through
  D-Bus only, not as a runit service.
- **Syslog through `socklog-void`** instead of journald. Service logs are
  under `/var/log/socklog/`, kernel messages in `kernel/`.
- **zram swap** is set up by Io's own runit service (`holo-zram-swap`)
  instead of systemd's `zram-generator`, with Valve's values: half of RAM,
  zstd, priority 100, zswap off.
- **earlyoom** runs with Valve's full argument set; its `--avoid` list names
  runit's processes instead of systemd.
- **`tmpfiles.d` rules** from Valve's packages are boot-time core services
  (`holo-dmi-rules`, `holo-fstab-repair`), since Void has no tmpfiles.
- **`CAP_SYS_NICE` for gamescope** is set as a file capability, exactly as
  on SteamOS, but by a boot-time core service, because gamescope comes from
  Void's package and an update would drop it.
- **Boot splash** is ended by `io-autologin` right before login. There is no
  controller firmware update splash (`plymouth-wrap`), since Io has no
  controller update service.

---

## Kernel

- **`linux-neptune-72`, 7.2.4**, built from Valve's `linux-integration` tree
  on top of Void's base configuration with Valve's `config-neptune` fragment
  merged in. SteamOS 3.8.4 runs 6.16.
- **`CONFIG_HID_HAPTIC=y`** is set in addition to Valve's fragment. It turned
  out to be unrelated to the trackpad haptics it was added for and will be
  removed with the next kernel build.
- **Kernel command line** lacks SteamOS's `amdgpu` options
  (`lockup_timeout`, `sched_hw_submission`, `dcdebugmask`,
  `ttm.pages_min`); to be compared after Alpha 2. `fbcon=rotate:1` rotates
  the text console.
- **No reboot on kernel panic.** SteamOS's panic sysctls are left out during
  the alpha phase: Valve pairs them with a crash log submitter, and without
  one a frozen device is more useful for debugging.

---

## Audio (`steamdeck-dsp`)

- **Noise suppression plugin:** Valve uses NoiseTorch's RNNoise LADSPA
  plugin (label `nt-filter`). Io builds werman/noise-suppression-for-voice as
  `rnnoise-ladspa` (label `noise_suppressor_mono`), because Void's NoiseTorch
  package ships no system-wide plugin.
- **No hardware profile switching.** SteamOS picks an audio profile at boot
  through symlinks in `/run`, because `/usr` is read-only. Io installs the
  Jupiter configuration directly into the standard search paths.
- **One merged `context.properties` file** instead of two overlapping ones.
- **Microphone loopback** is declared as PipeWire configuration. On SteamOS it
  is created by Valve's own patched WirePlumber (`CreateLoopback()`), which
  Void's upstream WirePlumber does not have. The source is currently named
  *Steam Deck Microphone*; SteamOS shows *Microphone*. SteamOS's matching
  loopbacks for speakers and headphones are not reproduced yet.
- **OLED (Galileo) parts removed.**

---

## Other ported packages

- **`deck-hw-support`** is frozen at Valve's `jupiter-hw-support`
  20250728.1: later versions rename the helpers to `holo-*`, but the Steam
  client still calls the `steamos-*` names. Several helpers are stubs, see
  [Helper status](Helper-Status). The automount udev rules are disabled.
- **`steamos-priv-write`** checks the `wheel` group instead of `deck` (as
  Valve's own polkit rule does) and logs through `logger`.
- **`xdg-desktop-portal-gamescope`** no longer aborts when there is no
  journald to log to.
- **`steamos-powerbuttond`** is version 3.1; SteamOS ships 4.2.
- **`jupiter-fan-control`** runs as a runit service; its `finish` script does
  what Valve's `ExecStopPost` does (hand the fan back to the embedded
  controller).
- **`steamos-tuning`** adds `kernel.pid_max = 4194304`, systemd's default that
  SteamOS inherits.
- **`timedatectl`** is a small replacement script; Steam only uses
  `set-timezone`.
- **Volume keys** are handled by `io-volumed`. SteamOS lets Steam handle them
  (`STEAM_ENABLE_VOLUME_HANDLER`); switching over is still to be tested.

---

## Not present on Io

System updates (`steamos-atomupd`), BIOS and dock firmware updates, factory
reset, controller firmware updates, the crash log submitter, the HDMI-CEC
daemon, mangoapp (performance overlay), Steam's input method modules, SDDM.
