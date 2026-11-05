# Alpha 7 — Valve's patches, restart into Io

**Released:** [alpha7](https://github.com/Lolzen/io-packages/releases/tag/alpha7)

**Goal:** after Alpha 6's SteamOS 3.9.2 parity, the gaps that showed in
daily use: *Restart* starting Io again, Steam's keyboard in the desktop,
and Valve's patches to the Void packages Io uses (kwin, Xwayland, Wi-Fi,
Mesa), carried as overlay packages. What is open afterwards is on
[Milestones](Milestones).

## Highlights

- ***Restart* from Io starts Io again**, and GRUB starts it without a menu.
- **Valve's Mesa patches:** OpenGL games follow Steam's frame limit, and
  RADV has Valve's fixes against stutter in game mode, for 64- and 32-bit
  games.
- **Steam's on-screen keyboard in the desktop** types German letters and
  emoji.
- **Five more overlay packages** with Valve's patches: kwin, Xwayland,
  wpa_supplicant, iwd and Mesa.
- **Valve's Deck modules in the initramfs**: adaptive brightness now moves
  Steam's brightness slider, as on SteamOS.
- **Twemoji**, SteamOS's emoji font.

## Changes

### Boot

- ***Restart* from Io starts Io again** (`io-base` 0.6.0). Io on an SD card
  has no boot entry of its own, so a restart used to start the internal
  SteamOS. A shutdown hook now sets UEFI `BootNext` to the firmware's entry
  for the card Io runs from, for the next boot only: switching the Deck off
  and on still starts SteamOS. See [Architecture](Architecture).
- **GRUB without its menu** (`io-base` 0.7.0): Io starts at once, as SteamOS
  does. The recovery stick keeps its menu.
- **Valve's Deck modules in the initramfs** (`steamos-tuning` 1.4), as
  SteamOS's initramfs hook has them on both models: the Deck's own drivers
  (`steamdeck` with its hwmon, LED and extcon parts) and the USB dual-role
  stack (DWC3), which Valve adds for the OLED's USB. dracut leaves them out
  on x86. The package rebuilds the existing initramfs once when the list
  changes. The recovery stick has them too.

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

### Graphics

- **Valve's Mesa patches** (`mesa-holo`, 64 and 32 bit): Void's Mesa 26.2.5
  with 14 of Valve's commits and three RADV fixes from Mesa main. OpenGL
  games now follow Steam's frame limit: Valve's patch turns V-Sync on while
  a limit is set, so glxgears with V-Sync off renders 30.0 FPS at limit 30
  and uncapped without a limit. RADV has Valve's
  fixes against stutter in game mode (per command buffer BO tracking, no
  global BO list for gamescope) and for *Forza Horizon* 4 to 6.

### Steam

- **USB over-current warning** (`io-steamos-manager` 0.15.0): the session
  half emits steamos-manager's `UdevEvents1.UsbOverCurrent` signal when the
  kernel reports that a USB port tripped; Steam's client knows the signal.
  Tested with a simulated event (a made-up port name): the signal arrives;
  Steam showed nothing for it in game mode. A real over-current is
  untested.
- **Adaptive brightness moves Steam's brightness slider** with the
  adjustment, as on SteamOS. It started right after `steamos-tuning` 1.4
  rebuilt the initramfs with Valve's Deck modules (see *Boot*); before,
  only the backlight followed and the slider stayed where it was set.

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

### Image build

- The image scripts put the repository keys (Void's and Io's) into each
  root before installing, so a build whose output goes into a log no longer
  stops at xbps's question whether to import a key.
- Four more overlays (`kwin-holo` with `kwin-devel-holo`,
  `xorg-server-xwayland-holo`, `wpa_supplicant-holo`, `iwd-holo`, see
  [Deviations](Deviations), *Io overlay*). In the generated template `${pkgname}` now means Void's name
  in the build functions too (`post_install` and the like, as in Void's
  template), not only outside functions.

### Packaging

- **A testing channel** for builds that are not merged yet: `build.sh` and
  `publish.sh` with `--testing` publish to the `testing` release of
  `io-repo`, which a Deck uses through `/etc/xbps.d/10-io-testing.conf`;
  `--replace` publishes the latest build even over the same or a higher
  published version (see [Building](Building)).
- **32-bit overlays:** an overlay with `lib32=yes` (Mesa) is built for
  i686 as well and published as `-holo-32bit` packages. `holo.sh` keeps
  their `provides`, which xbps-src drops for `-32bit` packages.
- `io-selftest.sh` checks `io-desktop` instead of 53 single packages (the
  package database check covers its dependencies) and no longer looks for
  leftovers of early alphas.

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

## Known limitations

- Controller navigation in game mode is sometimes dead after a boot until
  the Steam button is pressed. A Steam client bug (Steam Input at start),
  seen on SteamOS as well; reported as
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921).
- `€` (the AltGr level) from Steam's keyboard does not arrive in the
  desktop.
- The USB over-current signal is tested with a simulated event only.
- Steam's patch notes for system updates are still Valve's SteamOS notes.
- Formatting drives from Steam, the firmware updaters,
  suspend-then-hibernate and a factory reset are not part of this release;
  they are tested with the move to the NVMe (see [Milestones](Milestones)).
