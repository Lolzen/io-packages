# Alpha 2 — SteamOS behaviour from a reference capture

**Released:** [alpha2](https://github.com/Lolzen/io-packages/releases/tag/alpha2)

**Goal:** match real SteamOS behaviour wherever Io can, based on a reference
capture of SteamOS 3.8.4 on the same hardware instead of assumptions, and
ship an image that is reproducible from the repository alone.

Before any change, a full reference capture was taken on real SteamOS:
process environments and capabilities, every SteamOS Manager D-Bus value on
both buses, sysfs values, systemd units, configuration files, and a guided
D-Bus trace of 18 actions in game mode. Since then, Io's behaviour is
checked against that capture, not against documentation or memory.

## Highlights

- Game mode session rebuilt after Valve's `gamescope-session`: same Steam
  flags, gamescope arguments and environment. That alone brought back
  *Restart Steam*, the adaptive brightness toggle and the fan control toggle
- `io-steamos-manager` split into a root and a session half, like Valve's
  daemon, with values matching the capture
- KDE Plasma with SteamOS's application set
- The image is reproducible from the repository alone

## Changes

### Steam and game mode

- Steam flags `-steamos3 -steampal -steamdeck -gamepadui`, Valve's gamescope
  arguments and environment
- gamescope runs with `CAP_SYS_NICE` as a file capability, as on SteamOS;
  RTKit added for Steam's and PipeWire's realtime threads
- Portals limited to the gamescope backend in game mode, as on SteamOS
- VA-API: `mesa-vaapi` and `mesa-vaapi-32bit` (Void ships the driver
  separately)
- SSH toggle in Steam's developer settings works (`steamos-enable-sshd`)

### SteamOS Manager

- `io-steamos-manager` 0.3.0: root half on the system bus (runit service),
  session half on the session bus. TDP 3–15 W, GPU power profiles, desktop
  session name as captured. Setters report the value actually in effect.
  Replaces `io-priv-exec` and per-change `pkexec`
- Fan control and Wi-Fi power management helpers are real

### System

- Memory as on SteamOS: zram (50 % RAM, zstd, priority 100), zswap off,
  earlyoom with Valve's arguments and ordered after swap, `kernel.pid_max`
  raised. A nice limit and PAM patch SteamOS does not have were removed
- Logging: session output into a rotating log instead of tty1, kept across
  reboots in Steam's developer mode; `socklog-void` as syslog. A polkitd
  restarting every second was found and fixed; polkit starts through D-Bus
  only
- `seatd` removed: libseat uses elogind
- SSH sessions are closed before the network goes down at shutdown
- Storage expansion as an explicit user step (`io-grow-storage`, also in the
  desktop menu), util-linux only

### Audio

- The filtered microphone is visible in Steam: the loopback source needed a
  fixed format (2 channels, FL/FR), as Valve's WirePlumber patch sets

### Desktop and branding

- KDE Plasma in `io-desktop`, with OctoXBPS instead of Discover and Flatpak
- Io-branded Plymouth splash in the initramfs
- English throughout: messages, desktop entries, comments

### Tooling

- `publish.sh` uploads only new files and cleans stale release assets;
  `build.sh` copies packages into `void-packages` and can publish
- `io-selftest.sh` checks a running system (60 checks)

## Known limitations at release

- Screen recording produces clips without video
- First-boot Wi-Fi setup needs a keyboard
- SSH enabled with the default password (test phase)
