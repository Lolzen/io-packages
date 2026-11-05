# Beta 0.8 — Valve's SteamOS Manager, Io on the internal SSD

**Released:** [beta-0.8](https://github.com/Lolzen/io-packages/releases/tag/beta-0.8)

**Goal:** the first beta release. Io moves to the Deck's internal SSD, and
the parts that could only be tested there are tested: formatting drives,
the firmware updaters, hibernation and Steam's factory reset. Valve's own
SteamOS Manager takes over from Io's implementation, with runit support
written for Valve. Valve's packages for the Steam Deck OLED and the Steam
Machine are in place, untested. What is open afterwards is on
[Milestones](Milestones).

## Highlights

- **Valve's SteamOS Manager** in place of Io's own: everything Steam's
  settings and quick access menu talk to is now Valve's code, running on
  runit.
- **Io on the internal SSD:** the recovery stick installs it there, and
  *Repair Io* repairs an installation that does not start.
- **Steam's factory reset** works on Io, the way Io does it: user data at
  the next start, the system repaired in place with xbps.
- **Formatting SD cards and USB drives from Steam.**
- **Valve's firmware updaters:** Steam's BIOS and controller checks work
  as on SteamOS, and the updates run at boot with their splash.
- **Hibernation** with Io on the internal SSD, and suspend-then-hibernate
  for programs that ask for it.
- **SteamOS 3.9.3's packages:** the kernel `7.2.7-valve2` (on stable
  7.2.11), Valve's firmware updaters, `gpu-trace` 2.17 and more.

## Changes

### SteamOS Manager

- **Valve's `steamos-manager`** (Valve's main branch after 26.4.1) replaces
  `io-steamos-manager`, built from the branch `runit` of
  [Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager): seven
  commits that let it run without systemd, offered to Valve. It finds the
  init system at start; on systemd nothing changes. On runit it switches
  system services through runit (fan control, the LAVD scheduler, the
  Wi-Fi backend), takes the login mode from the session, runs Orca as its
  own child and restarts it when it fails, logs out through logind, and
  refuses calls from games by Steam's `reaper` among the caller's parents.
  Tested on the Deck: fan control, the scheduler, switching the Wi-Fi
  backend both ways, the screen reader, switching between game mode and
  desktop both ways, calls from a game refused. See
  [Architecture](Architecture).
- **`io-atomupd`** (new) serves Steam's update API (`Atomupd1`) and
  `steamos-update` with xbps behind them, as `io-steamos-manager` did.
- **Io's session side** of Valve's user units: `io-manager-session` writes
  cecd's configuration, starts cecd and SteamOS Manager's session half,
  and cleans up a one-shot desktop login. SDDM's settings are installed
  under Valve's name (`holo.conf`), and Valve's `holo-session-select` with
  Io's desktop session is `steamos-session-select`.
- *Return to Gaming Mode* is Valve's command again (`steamdeck-kde-presets`).

### Installing and repairing

- **The recovery stick installs Io on the internal SSD** (*Install Io*),
  tested on the Deck's NVMe.
- **Repair Io** (recovery stick): check and repair the filesystems,
  rebuild the initramfs, reinstall the boot loader, forget a hibernated
  session that does not resume, check the installed packages, request a
  factory reset, open a root shell. Tested on the internal NVMe.
- **Old kernels are removed** after a kernel update (`io-base` 0.7.1).

### Factory reset

- **Steam's factory reset** (Settings → System) runs Io's
  `io-factory-reset` through `steamos-reset-tool`, the command Steam's
  client runs on SteamOS 3.9.3. The user data is erased at the next start,
  before any service; the system is updated, packages installed on top of
  Io are removed and changed packages installed again, all with xbps; the
  update channel goes back to the image's, as SteamOS falls back to
  stable. Tested from Steam: the Deck restarts, the user data is gone,
  Steam's first setup follows. See [Deviations](Deviations), *Factory
  reset*.
- `FactoryReset1` and Valve's `steamos-factory-reset-config` lead to the
  same reset.

### Drives

- **Formatting from Steam:** Valve's helpers and `format-device.sh`, with
  Io's check that refuses the disk Io runs from. Tested with an SD card and
  a USB drive (card check with `f3probe`, ext4, mounted for `deck`), and
  refused for the internal SSD while Io ran from a card.

### Firmware

- **Valve's BIOS and controller updaters** (`deck-firmware-updaters`, from
  SteamOS 3.9.3's `jupiter-hw-support`): Steam's checks answer as on
  SteamOS, and both updates run at boot before the login manager, the
  controller update with its splash in Io's theme. Tested: the check modes
  at boot and from Steam, and the update at boot with Valve's simulated
  controller update. Io's controller updater never flashes older firmware
  over newer.
- **Valve's dock firmware updater** (`jupiter-dock-updater-bin`) for
  Steam's dock check and `UpdateDock1`; untested without Valve's dock.
- **Valve's thumbstick and trigger calibration tools**
  (`deck-controller-calibration`), run by hand in a terminal.

### Power

- **Hibernation**, allowed only with Io on the internal SSD (on an SD card
  or USB drive it would take minutes and wear the medium). Valve's
  settings of SteamOS 3.9.2: suspend-then-hibernate after 20 minutes for
  programs that ask for it. Io resumes through its own EFI variable and
  dracut module. Tested: hibernating and resuming. Steam's *Standby* is a
  plain suspend, on SteamOS as well.
- **kwin's suspend patches** from Valve's kwin 6.7.3-1.7 (`kwin-holo`):
  the screens go off before suspend.

### Wi-Fi

- **Steam keeps the Wi-Fi backend in the desktop too**
  (`STEAM_USE_WPASUPPLICANT=1` in both sessions). Before, Steam switched to
  iwd in the desktop and back in game mode, with a short drop and a
  password prompt for known networks.
- **`wpa_supplicant-holo`:** the rescan fixes as merged in hostap.
- **`iwd-holo`:** Valve's fourth patch from SteamOS 3.9.3, scanning only
  the bands the adapter supports.
- **`NetworkManager-holo` 1.58.1:** `wheel` may save a network for all
  users without a password, as on SteamOS.

### Steam Deck OLED and Steam Machine (untested, no hardware)

- **OLED:** Valve's audio differences for it (SOF firmware, its own filter
  chain, the speaker filter graph), the mura correction (`galileo-mura`),
  the 45–90 Hz refresh range and HDR by default, and Wi-Fi debug mode.
- **Steam Machine:** Valve's audio profile (HDMI/DisplayPort, AC3 for
  ARC), EC logging (`ec-log`), waking from the TV through its embedded
  controller (SteamOS Manager).
- Nothing of this runs on the LCD.

### Kernel and Valve's packages

- **`linux-neptune-72` 7.2.11:** Valve's `7.2.7-valve2` (SteamOS 3.9.3)
  with stable 7.2.11 merged in. See [Kernel](Kernel).
- From SteamOS 3.9.3: `gpu-trace` 2.17, `holo-realtek-firmware-toggles` 1.4.
- `io-branding` 0.3.1: one boot logo again; the initramfs follows the
  theme.

### Image build and packaging

- The image build mounts `/dev`, `/proc` and `/sys` for the package
  install, as void-mklive does, so Python's byte-compiling no longer fails.
- `publish.sh` picks the newest package by xbps's own version order.

## Decided

- **SteamOS Manager is Valve's own** from now on; Io's runit support goes
  to Valve as a merge request rather than staying a fork.
- **NetworkManager's iwd patches** (mirroring connections into iwd) stay
  out: wpa_supplicant is the backend.

## Known limitations

- The Steam Deck OLED, the Steam Machine and Valve's dock are untested.
- A real BIOS or controller update is untested (only the checks and
  Valve's simulated update).
- Hibernating from Plasma's menu and suspend-then-hibernate from Plasma's
  energy settings are untested.
- A fresh user is asked once for screen sharing when Steam starts in the
  desktop; SteamOS does not ask.
- `€` (the AltGr level) from Steam's keyboard does not arrive in the
  desktop.
- Controller navigation in game mode is sometimes dead after a boot until
  the Steam button is pressed (Steam's,
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921)).
- Steam's patch notes for system updates are Valve's SteamOS notes.
