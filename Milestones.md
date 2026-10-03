# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 5](Alpha-5); Alpha
6 gets its page once its theme is chosen.

---

## Alpha 6 (next, theme not chosen yet)

Candidates from what is open:

- **Decisions:** Valve's Mesa patches; system updates from Steam (today
  `steamos-update` and `steamos-select-branch` are stubs); VRAM priority
  for the foreground game (see *Later milestones*)
- **Tests:** everything under *Tests pending*
- **Checks needing Valve's files:** `linux-firmware-neptune` against Void's
  firmware packages, `holo-sudo` against Valve's PKGBUILD, whether a game
  notices the missing `lib32-gamescope`
- **Open observations** below

---

## Open observations

- **Roaming** between router and repeater with the same network name: the
  Deck held on to the weak connection (seen with iwd, before
  `wireless-regdb`). Compare with wpa_supplicant
- **Steam's developer settings:** *Use Legacy X11* is missing (not a
  gamescope version question — 3.16.30 does not show it either);
  *speaker-test* does nothing
- **Screen sharing prompt in the desktop:** Steam asks Plasma's portal for
  screen sharing at start; the prompt appears until *Allow restoring* is
  chosen once. Check what SteamOS does for a new user
- **vpower's shutdown at 0.5 %:** never tested on a real empty battery
- **`Previous system reset reason`** in the kernel log once: watch whether it
  comes back
- **Wi-Fi next to the dock's Ethernet showed "can't reach network"** once,
  during a day of heavy testing; plugging and unplugging the dock later
  behaved correctly. If it comes back, record before reconnecting:
  `nmcli -f DEVICE,STATE,IP4-CONNECTIVITY device; nmcli -f CONNECTIVITY
  general; ip route`
- **`/` was world-writable** (mode 777, changed on 2026-09-25 during the
  boot analysis; no package and no automount run explains it). Fixed by
  hand; it has stayed 755 since, also with Alpha 5's automount, which
  leaves the disk Io runs from alone. `io-selftest.sh` checks it; check
  fresh images with it before each release
- **The first dock hot-plug after many session restarts showed no picture**
  on the TV; after a reboot, plugging and unplugging worked every time

---

## Tests pending

- **Drives in Steam:** a drive that already carries a Steam library (Steam
  should take it over), and ejecting a drive from Steam
- **Decky Loader**
- **SteamOS Devkit Client:** pairing and deploying (the service answers and
  is visible on mDNS)
- **Notifications in game mode from a game:** `steam_notif_daemon` hands
  them to Steam (Steam logs `ExecuteSteamURL … open_xdg_notification`), but
  Steam showed nothing for a test sent with `busctl`. Steam probably only
  shows notifications of processes it knows; check with a game that sends
  one

---

## Needs hardware to test

Parts that can be built, but not tested without hardware Georg does not
have. They are to become issues and draft pull requests, marked as needing
someone with the hardware.

- **Valve's Docking Station:** its firmware updater (`hub_update`, today a
  stub that reports "up to date"), and HDMI-CEC with a dock that passes it
  through (`/dev/cec*`); cecd and the switches in Steam work, the TV side is
  untested
- **Steam Deck OLED:** Io is built for the LCD model; the OLED needs its own
  Wi-Fi driver path (ath11k), Valve's Galileo audio profile and firmware,
  and the display quirks

---

## Polish

- Designed boot splash; the black gap while Steam loads inside gamescope
- Plasma: messages when switching modes, Valve's nested desktop (Plasma
  inside game mode)
- **Theming:** whether `void-artwork` still belongs in `io-desktop`

---

## Later milestones

- **Kernel metapackage** `linux-neptune`, with the next kernel update
- **VRAM priority for the foreground game**, what Valve's `dmemcg-booster`
  does on SteamOS: the kernel side (`CGROUP_DMEM`) is there, Valve's daemon
  depends on systemd's units and slices. Needs a design of Io's own, for
  example gamescope and Steam in a cgroup of their own
- **Installing to the internal NVMe**, once SteamOS on it is no longer needed
  as the reference; suspend-then-hibernate comes with it (Valve's resume path
  keeps the swap file's position in an EFI variable through systemd)
- **Formatting drives from Steam** (from Alpha 5): Valve's `format-device.sh`
  is in place with Io's check against formatting the disk Io runs from;
  `FormatDevice` and the format helpers still refuse. Tested together with
  the move to the NVMe: first against the internal SSD while Io runs from
  the card (its SteamOS is wiped then anyway; Valve's device list must
  refuse it), then, with Io on the NVMe, against SD cards and USB drives
- **Firmware updaters** (from Alpha 5): a check mode for `jupiter-biosupdate`,
  `jupiter-controller-update` and `jupiter-dock-updater`, so Steam can show
  whether an update is due, and flashing last, if at all. The BIOS updater
  needs Valve's BIOS files and flash tool (`h2offt`); until then SteamOS on
  the same Deck keeps the firmware current
- **Catching up with Valve:** once Io matches SteamOS 3.8.4 apart from its
  documented deviations, one review round against Valve's newest version of
  every ported package, then one large update. Until then SteamOS 3.8.4
  stays the reference
- **System updates from Steam:** Steam moves from `steamos-update` to a D-Bus
  API (`atomupd-manager`), which `io-steamos-manager` could serve with
  `xbps-install -Su` behind it
- **A factory reset of Io's own** (fresh home directory): a design decision,
  and destructive
- **Live ISO with an installer**, once self-built void-mklive ISOs boot
  (they drop to dracut's emergency shell, cause not found yet); after it,
  **flavours**: *Plasma* (today's image),
  *Base* (game mode only), *Slim* (a light desktop). The split is prepared:
  `io-base` is the core, `io-desktop` adds the desktop
- **For 1.0:** SSH off in images, as on SteamOS; a way to replace the
  default password on first boot. 1.0 is the beta (`beta1.img`,
  `beta1.iso`)

---

## Recurring

- `pkgcheck.sh`: Valve's package versions against Io's
- Valve's kernel updates, with the configuration review described on
  [Kernel](Kernel)
- Boot logs, for regressions and new warnings
- After each gamescope update: *Use Legacy X11* in Steam's developer
  settings
