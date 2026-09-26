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

### Audio

- **Loopbacks for the speaker too**, as on SteamOS 3.8.4. Applications talk
  to a loopback in front of the speaker, which keeps its two channels when
  the speaker itself is rebuilt. Without it, switching *Mono audio* back
  off closed Steam's own interface sound until the next login

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

### Helpers

- `steamos-devkit-mode` is real
- `jupiter-dock-updater --check` answers "up to date": it answered "update
  available", and Steam announced a dock update at every start

### Upstream

- **Void's gamescope is 3.16.30** (Io's update, merged): screen recording
  works on a stock image
