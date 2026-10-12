# Alpha 7

**Status:** in progress. What is still open is on [Milestones](Milestones).

## Changes so far

### Boot

- ***Restart* from Io starts Io again** (`io-base` 0.6.0). Io on an SD card
  has no boot entry of its own, so a restart used to start the internal
  SteamOS. A shutdown hook now sets UEFI `BootNext` to the firmware's entry
  for the card Io runs from, for the next boot only: switching the Deck off
  and on still starts SteamOS. See [Architecture](Architecture).
- **GRUB without its menu** (`io-base` 0.7.0): Io starts at once, as SteamOS
  does. The recovery stick keeps its menu.

### Desktop

- **Steam's on-screen keyboard in the desktop** types German letters and
  emoji: `xorg-server-xwayland-holo` passes its text on as keysyms over
  libei, and `kwin-holo` accepts them (libei 1.6) and passes them past the
  input method (Valve's patches). `€` (AltGr level) still does not arrive.
- **The desktop keeps the brightness set in game mode** through Valve's
  kwin patch in `kwin-holo`; `io-plasma` no longer writes it into kwin's
  configuration (`io-session` 0.7.2).
- **No black flash when returning to game mode:** the desktop's last
  picture stays until Steam's boot animation, as on SteamOS. Valve's two
  Xwayland reverts meant for this caused the flash on Io and are left out.
- External displays are no longer offered modes below 480p, unless a
  display has no other (`kwin-holo`).
- **Twemoji**, SteamOS's emoji font (`ttf-twemoji-default`, built as Valve
  builds it), the emoji font for the whole system through its fontconfig
  file.

### Steam

- **USB over-current warning** (`io-steamos-manager` 0.15.0): the session
  half emits steamos-manager's `UdevEvents1.UsbOverCurrent` signal when the
  kernel reports that a USB port tripped; Steam's client knows the signal.
  Tested with a simulated event (a made-up port name): the signal arrives;
  Steam showed nothing for it in game mode. A real over-current is
  untested.

### Wi-Fi

- **`wpa_supplicant-holo`:** Valve's patches (a wrong WPA3 password is
  reported as such with more access points; fewer forced rescans after
  resume) and some of the options Valve's build enables and Void's does
  not, among them WNM and MBO for roaming between access points.
- **`iwd-holo`**, for iwd as backend: Valve's three fixes to scanning and
  connecting.
- **`wireless-domain-setter`** (Valve's, new; runit service on every
  model): copies the regulatory domain of a self-managed card (the OLED's
  ath11k) to the kernel, for cards that follow the global domain such as
  Valve's USB streaming dongle, whose driver it also reloads at boot. On
  the LCD it ends at once.

### Steam Deck OLED (untested, no hardware)

- **Audio:** Valve's SOF firmware for the OLED's audio DSP, its own filter
  chain configuration and Valve's speaker filter graph (`steamdeck-dsp`).
- **Display:** Valve's mura correction (`galileo-mura`, new), the 45–90 Hz
  refresh range and HDR on by default, as Valve's game mode session sets
  them for the OLED.
- **Wi-Fi:** Steam's Wi-Fi debug options (`WifiDebug1`, `WifiDebugDump1`)
  and the ath11k card's regulatory domain handed to the kernel (see
  *Wi-Fi* above).
- **Initramfs:** Valve's Deck modules, which SteamOS puts into the initramfs
  on both models: the Deck's own drivers and the USB dual-role stack (DWC3),
  which Valve adds for the OLED's USB (`io-base` 0.7.1, and the recovery
  stick).
- The selftest skips the check for the LCD's Realtek Bluetooth firmware on
  the OLED.

### Image build

- The image scripts put the repository keys (Void's and Io's) into each
  root before installing, so a build whose output goes into a log no longer
  stops at xbps's question whether to import a key.
- Four more overlays (`kwin-holo` with `kwin-devel-holo`,
  `xorg-server-xwayland-holo`, `wpa_supplicant-holo`, `iwd-holo`, see
  [Deviations](Deviations), *Io overlay*). In the generated template `${pkgname}` now means Void's name
  in the build functions too (`post_install` and the like, as in Void's
  template), not only outside functions.

## Checked against SteamOS 3.9.2

- **`zenity`:** Void's version behaves as Valve's `zenity-gtk3`; nothing to
  port.
- **`inputattach-cec-units`:** only for Pulse-Eight and RainShadow USB-CEC
  adapters; not needed.
- **Steam's patch notes for system updates** are Valve's latest SteamOS
  notes for the update channel, on Io as well; they stay (see
  [Deviations](Deviations)).
- **The screen sharing prompt** when Steam starts in the desktop: the
  permission store looks as on SteamOS apart from the app ID, and neither
  grants it in advance. A fresh user is still to be tried.
- **The question before switching to the desktop** ("Are you sure?") comes
  with Steam's client, not the system: on Io the stable client switches
  after a short countdown without asking; the beta client asks, as on
  SteamOS (whose captures ran the beta client).

## Decided

- **`void-artwork`** stays: `plymouth-data` depends on it (Void builds
  Plymouth with its logo), and Io's GRUB uses none of it.
