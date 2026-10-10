# Alpha 3 — Parity & quality of life

**Released:** [alpha3](https://github.com/Lolzen/io-packages/releases/tag/alpha3)

**Goal:** close the many small gaps to SteamOS that had piled up, and make
everyday use smoother.

## Highlights

- Steam as on SteamOS (`steam-jupiter`): Deck branch, preinstalled client,
  first boot without keyboard or Ethernet
- Audio as on SteamOS: loopbacks with Steam's localized device names, the
  filter chain in its own PipeWire instance
- Steam's performance overlay (mangoapp), gamemode
- Valve's Plasma defaults with Steam's on-screen keyboard in the desktop
- Boot 12 s faster

## Changes

### Steam and game mode

- **`steam-jupiter`**, Valve's Deck packaging of Steam, replacing Void's
  `steam`: a preinstalled client on `steamdeck_stable` (Io had been on the
  desktop client's branch), Valve's wrapper adding `-steamdeck -pipewire`,
  udev rules for input, status LED and wakeup, and 48 additional 32-bit
  libraries. With `libnm-32bit`, Steam's first-run setup handles Wi-Fi with
  the Deck's own controls; verified on a fresh image with neither keyboard
  nor Ethernet. `io-netcheck` is gone
- **mangoapp** for Steam's performance overlay, started per session;
  **gamemode** on demand through D-Bus
- **vpower** (Valve's battery daemon): battery metrics for Steam, controlled
  shutdown at 0.5 %. Patched to find its hwmon directory.
  **`holo-upower-config`** hands UPower's critical action to it, with Valve's
  `yes`/`true` bug fixed
- Steam's own volume handler (`STEAM_ENABLE_VOLUME_HANDLER`); `io-volumed`
  dropped
- `steam-im-modules`: Steam's on-screen keyboard as input method in GTK 3/4
  and Qt 5 apps

### Audio

- ALSA loopbacks created at runtime by Io's port of Valve's
  `CreateLoopback()`, carrying the card identity: Steam shows its own
  localized device names
- Filter chain in its own PipeWire instance with Valve's quantum, locked
  memory and single malloc arena
- `deck-firmware-cirrus` dropped: Void's `linux-firmware` ships newer CS35L41
  files, including the Deck-specific `vlv1776`
- ALSA's default device routed through PipeWire (`io-base`)

### Desktop

- `steamdeck-kde-presets` 3.9.4: Steam autostarts in the desktop — Steam's
  on-screen keyboard (Steam + X) and an end to the periodic desktop freezes
  (without Steam holding the controller, the kernel dropped the trackpad
  pointer whenever Plasma reopened it). Vapor theme, power and locker
  settings, KWallet, IBus, *Return to Gaming Mode*
- Steam draws in real pixels next to Plasma's 135 % (`DPIScaling` 0)

### System and boot

- `LANG` in the session and every Steam language generated
- Kernel command line as on SteamOS (`amdgpu` timeouts and options,
  `ttm.pages_min`); GTT 8192M as on SteamOS
- `deck-hw-support` 20260807.1: sturdier `jupiter-check-support`,
  restructured GPU reset rules, Valve's cursor theme
- Boot: Steam UI after 42 s instead of 54 s (`io-netcheck` waited 10 s on
  every boot)
- Clean-up: fallback kernel, unused kernel config, stray services and
  dependencies removed; `build.sh` pulls `void-packages` first

## Known limitations at release

- Screen recording produces clips without video
- Wi-Fi backend: Io runs wpa_supplicant, SteamOS 3.8.4 iwd; switching not
  implemented
- No automount of SD cards and USB drives
- SSH enabled with the default password (test phase)
