# Alpha 4 — Parity II: SDDM, screen recording, Wi-Fi

**Released:** [alpha4](https://github.com/Lolzen/io-packages/releases/tag/alpha4)

**Goal:** planned as the storage release, Alpha 4 became a second large
parity round. The loose ends from Alpha 3 turned out to be the bigger
gains; automount and formatting moved on to Alpha 5.

## Highlights

- **SDDM** logs in and switches sessions as on SteamOS
- **Screen recording works** — open since Alpha 2
- **Wi-Fi** as in Valve's current configuration, with the backend
  switchable from Steam
- Steam's performance overlay follows Steam's level setting again
- LAVD CPU scheduler, system report, Valve's swap file

## Changes

### Login and sessions

- **SDDM** replaces Io's own login (`agetty` autologin on tty1 and the
  session loop in `io-start`): autologin into game mode, and a fresh login
  whenever a session ends (`Relogin=true`), as on SteamOS. Sessions are real
  PAM/elogind sessions on `seat0`; audio keeps working across session
  restarts. The splash goes to black and then to game mode, as on SteamOS
- **Session switching as on SteamOS:** `SessionManagement1` in
  `io-steamos-manager` writes SDDM's one-shot login file
  (`zzt-steamos-temp-login.conf`) or the default login mode
  (`zz-steamos-autologin.conf`) and ends the running session. Plasma is
  logged out through its own session manager (`org.kde.Shutdown.logout`),
  as SteamOS's *Return to Gaming Mode* does. `DefaultLoginMode` can be set,
  so booting into the desktop works (`steamos-session-select
  plasma-wayland-persistent`)
- **GPU reset** restarts SDDM, as Valve's rule does — any session, the
  desktop included; `steamos-restart-sddm` is real
- tty1 is a plain login console again; the memlock limit for the filter
  chain comes from `limits.d`

### Screen recording

Two separate causes, both fixed:

- **Steam's 32-bit client lacked PipeWire's 32-bit plugins.** Void splits
  what Arch's `lib32-pipewire` ships into `pipewire-32bit` and
  `libspa-*-32bit`; `steam-jupiter` only pulled the library. Without the
  support plugins Steam could not create its PipeWire main loop, without the
  converters it could not connect the capture stream
- **gamescope before 3.16.22 never finished negotiating** with PipeWire 1.6
  (it iterated its PipeWire loop without entering it). Void's gamescope is
  3.16.20; an update to 3.16.30 is submitted to Void. Until it is merged,
  recording needs a gamescope of 3.16.22 or later

### Wi-Fi

- Backend as in Valve's current configuration: wpa_supplicant by default,
  iwd selectable through Steam's *Force WPA Supplicant Wi-Fi backend*.
  `steamos-networking-tools` ported to runit; iwd is a runit service linked
  only while it is the backend
- The interface is called `wlan0`, as on SteamOS (`net.ifnames=0`)
- Wi-Fi power save survives reconnects and backend switches, for both
  backends
- IPv6 privacy extensions, a connectivity check (GNOME's endpoint), and
  `wireless-regdb`: the Deck now uses the country's radio rules instead of
  the world-wide minimum

### Game mode

- mangoapp now starts after the session environment is complete: before, it
  missed Steam's configuration file and showed its default overlay in every
  game, whatever level Steam had set
- gamescope's statistics pipe (`-T`, `GAMESCOPE_STATS`) as on SteamOS
- `steamos-powerbuttond` 4.2 from Valve's source; it ends when the desktop
  starts, so power button presses reach Plasma there
- `jupiter-initial-firmware-update`: Valve's script (exits at once on
  Jupiter)

### SteamOS Manager and tools

- **LAVD CPU scheduler** (`CpuScheduler1`): `none` and `lavd`, through a
  runit service reading Valve's `/etc/default/scx`. Steam shows no switch
  for it, on SteamOS neither; the interface is there for tools such as
  Decky plugins
- **`steamos-systemreport`**: Valve's report, changed only where it would
  miss its purpose (socklog and session logs instead of the journal, xbps
  instead of pacman). Works from Steam's UI, including saving to the
  desktop
- `WifiBackend` writable; `io-steamos-manager` 0.6.0

### System and boot

- Valve's 1 GiB swap file in `/home` next to zram
- Hibernation allowed only with `/` on the internal NVMe; on an SD card or
  USB stick nothing offers it
- From `steamos-customizations-jupiter`: early HID drivers (controllers are
  claimed before Steam falls back to evdev), Valve's scheduler tunings, X11
  virtual display size, wake-on-Bluetooth for Valve's adapter
- Initramfs: the SD card modules load before `amdgpu`, so card detection
  overlaps `amdgpu`'s 3.7 s load
- `gstreamer1-pipewire`, as on SteamOS

## Known limitations at release

- No automount of SD cards and USB drives, no formatting from Steam
- Screen recording needs gamescope 3.16.22 or later, which Void does not
  ship yet (update submitted)
- Steam's developer settings: *Use Legacy X11* is missing; *speaker-test*
  does nothing
- SSH enabled with the default password (test phase)
