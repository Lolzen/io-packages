# Alpha 5 — in progress

**Not released yet.** This page collects what is done since
[Alpha 4](Alpha-4) and is completed at release. What is still open is on
[Milestones](Milestones).

**Goal:** storage as on SteamOS — SD cards and USB drives mount on their
own and can be formatted from Steam. Before that, a third parity round
closed the small items left from Alpha 4.

## Highlights

- **Screen reader:** Steam's accessibility option reads the interface
  aloud (Orca through speech-dispatcher and espeak-ng), with voices,
  speed, pitch, volume and controller shortcuts
- **HDMI-CEC** as on SteamOS 3.8.4: `cecd` and `cec-audio-control`
- **Firewall** with Valve's rules, and Plasma's firewall page
- **SteamOS Devkit Client** support: the Deck announces itself on the
  network and can be paired
- **Mono audio**, download mode, and a fix that kept every session after a
  switch alive in the background
- **Game mode completed as on SteamOS 3.8.4:** Steam's notifications, the
  holo portal (color scheme and app chooser for games), Valve's
  `steam-launcher` with the short-session tracker, the low-disk check, and
  `drm_janitor` when the session ends
- **Kernel configuration as Valve builds it**, with Io's own overrides
  documented one by one ([Kernel](Kernel)); NTSync loaded at boot
- **Valve's UCM profile in effect** (*Internal Mic*, headphone sink), and
  adaptive brightness confirmed working

## Changes

### Sessions

- **Logging out ends every process of the session** (`KillUserProcesses`,
  as on SteamOS). With SDDM a session switch is a logout; before, the old
  session's D-Bus bus and everything started with `setsid` kept running —
  a whole Plasma after each switch. Relogin is noticeably faster
- **io-steamos-manager's user half starts in every session.** The session
  script used to skip it when one was running — and found the previous
  session's, still on its way out after SDDM's relogin. The new session
  was then left without one, and Steam's settings for TDP, fans and the
  like silently did nothing
- **Steam starts through Valve's `steam-launcher`**, with Valve's
  short-session tracker before and after it, as `steam-launcher.service`
  does: after three quick failed starts Steam repairs itself, and a client
  deployed by the Devkit Client is used
- **Valve's low-disk check** before game mode starts: under 500 MB free,
  installed games are deleted, least recently changed first, until there is
  room again (their `compatdata` stays)
- **Steam's notifications in game mode** (`steam_notif_daemon`), and
  **`drm_janitor`** resetting the display state when gamescope exits
- **The holo portal first in game mode**, as on SteamOS
  (`default=holo;gamescope`): Settings (color scheme, contrast, accent
  color) and the app chooser answer instead of *No working backend*
- The `STEAM_*MANGOAPP*` variables and the GTK cursor theme for Steam, as in
  Valve's session
- **Leftovers from the agetty days removed:** the 15-second wait for
  `/run/user`, the `XDG_RUNTIME_DIR` exports, and ending PipeWire and the
  power button daemon by hand (the login's end does it)
- Steam's update screen gets a full-screen picture, like Valve's

### SteamOS Manager (`io-steamos-manager` 0.10.0)

- **`LowPowerMode1`:** while Steam holds a download handle, the TDP is
  lowered to 6 W (Valve's `download_mode_limit` for the Deck) and restored
  afterwards
- **`Audio1`:** Steam's *Mono audio* (Accessibility) sets WirePlumber's
  `node.features.audio.mono`
- **`HdmiCec1`:** Steam's two HDMI-CEC switches write the same cecd
  settings as steamos-manager (`00-` and `99-steamos-manager.toml`,
  captured on SteamOS), and cecd reloads them
- **`ScreenReader0` and `ScreenReader1`:** Valve's logic step by step —
  Orca's settings file, voices from speech-dispatcher, a virtual keyboard
  for Orca's shortcuts
- `WifiDebug1` is not needed: SteamOS 3.8.4 does not offer it on the Deck
- **Orca's shortcuts only while Orca runs.** Steam sets the screen reader
  mode at every start; without Orca the key presses reached the focused
  window (`aa` in Plasma's search)
- Wi-Fi power save for iwd keeps the comments in `/etc/iwd/main.conf`
- The Plasma logout fallback matches the wrapper's real process name

### Audio

- **Loopbacks for the speaker too**, as on SteamOS 3.8.4. Applications talk
  to a loopback in front of the speaker, which keeps its two channels when
  the speaker itself is rebuilt. Without it, switching *Mono audio* back
  off closed Steam's own interface sound until the next login
- **Valve's UCM profile takes effect:** Void's `alsa-ucm-conf` ships a link
  that UCM finds first by the card's long name; it is kept out now. The
  microphone is *Internal Mic* again and the headphone sink is there
- **`wireplumber-elogind`** installed: WirePlumber follows the active session
  on the seat

### Kernel

- **Configuration in layers:** Void's base, Valve's full configuration and
  `config-neptune`, then Io's overrides with a reason each; from about 1,220
  differences to Valve's configuration down to 24, see [Kernel](Kernel)
- **NTSync** is a module now, as on SteamOS, and loaded at boot (Valve's
  `modules-load.d/ntsync.conf`)

### System

- **No polkit rule of Io's own** for power actions: the session is active
  under SDDM, so elogind's policy allows them, as on SteamOS
- **`iio-sensor-proxy` removed:** Steam reads the light sensor itself;
  adaptive brightness works without it
- `timedatectl` takes only zone names, fails on unknown commands and no
  longer writes `/etc/timezone`; `steamos-set-hostname` works without
  `hostnamectl`
- elogind's D-Bus activation file stays out on elogind updates
- Valve's sysctl files verbatim, plus what SteamOS inherits from Arch and
  systemd; Valve's `holo-fstab-repair` script as it is
- `jupiter-fan-control` runs through `vsv` with a log service, and survives
  the update from the old layout
- The Plymouth theme is set only on first install; `/etc/vpower.toml` keeps
  local changes
- `/usr/share/i18n/SUPPORTED` from Void's locales; 32-bit `json-glib` and
  `libvdpau` for Steam's runtime diagnostics

### Image

- **UTC as the default time zone** (Steam sets the user's zone); vim and
  nano instead of nvi, as on SteamOS
- `mkiso.sh` and the void-mklive patch removed; they no longer worked

### New packages

- **`holo-sudo`:** Valve's sudoers files, including `no-fqdn` (sudo does not
  hang resolving the host name without a network)
- **`holo-realtek-firmware-toggles`:** Valve's tool for Realtek USB Wi-Fi
  sticks, as it is
- **`steam-web-debug-portforward`:** Steam's CEF debugging port on the
  network (8081 → 8080), a runit service with `socat`
- **`jupiter-firewall`:** Valve's rules (SSH, DHCPv6 and every port from 1024
  up in; the privileged ports below rejected) with ufw and
  `plasma-firewall` — Void has no firewalld
- **`cecd` 0.2.0 and `cec-audio-control` 0.1.0**, the versions of SteamOS
  3.8.4, started with each session
- **`steamos-devkit-service`:** Valve's service, publishing the Deck on mDNS
  through Avahi instead of systemd-resolved; Steam's developer mode
  switches it
- **`gpu-trace`** 2.14, as on SteamOS 3.8.4: Steam's system tracing in the
  developer settings
- **`io-release`:** Io's `os-release` and `lsb_release`, which Steam shows
  under Settings → System
- **`steam_notif_daemon`** 1.0.1, **`xdg-desktop-portal-holo`** 0.1.18 and
  **`drm_janitor`** 0.0.4, the versions of SteamOS 3.8.4

### Helpers

- `steamos-devkit-mode` is real
- `jupiter-dock-updater --check` answers "up to date": it answered "update
  available", and Steam announced a dock update at every start

### Packaging

- `homepage` fields as in Valve's PKGBUILDs; the license files Valve's
  sources carry are installed
- `publish.sh` stops on signing errors instead of hiding them

### Upstream

- **Void's gamescope is 3.16.30** (Io's update, merged): screen recording
  works on a stock image
