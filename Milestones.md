# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog); what is done since the last release is on the
page of the release in progress ([Alpha 5](Alpha-5)).

---

## Alpha 5 — Storage (next)

**Goal:** games on every drive the Deck can use, as on SteamOS — SD cards
and USB drives mount on their own and can be formatted from Steam. Risky
steps (anything that writes to drives or firmware) come last.

- [ ] **Automount** for SD cards and USB drives: Valve's
      `block-device-event.sh` and `steamos-automount.sh` on runit instead of
      `systemd-run` (`setsid --fork`), leaving out the boot device; Steam
      then offers the drive as a library. Check udisks2 for Valve's
      `as-user` changes; `Storage1` in `io-steamos-manager` belongs here
- [ ] **Formatting from Steam:** `steamos-format-sdcard` /
      `steamos-format-device` become real (Valve's `format-device.sh`)
- [ ] **`steamos-trim-devices`:** implemented, never tried from Steam
- [ ] **Firmware updaters, check mode first**, so Steam can show whether an
      update is due: `jupiter-biosupdate` (bash and `h2offt`),
      `jupiter-controller-update` (Python: `hid`, `crcmod`, `click`,
      `progressbar`), `jupiter-dock-updater` (needs a dock). Flashing itself
      last, if at all — SteamOS on the same Deck does it anyway

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
  hand; `io-selftest.sh` checks it now. Check a fresh image before release
- **The first dock hot-plug after many session restarts showed no picture**
  on the TV; after a reboot, plugging and unplugging worked every time

---

## Tests pending

- **Headphones** with the speaker loopback (plugging in and out switches
  the sound)
- **SteamOS Devkit Client:** pairing and deploying (the service answers and
  is visible on mDNS)

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
- Plasma: messages when switching modes, the notification service requested
  in game mode, Valve's nested desktop (Plasma inside game mode)

---

## Later milestones

- **Kernel metapackage** `linux-neptune`, with the next kernel update
- **Installing to the internal NVMe**, once SteamOS on it is no longer needed
  as the reference; suspend-then-hibernate comes with it (Valve's resume path
  keeps the swap file's position in an EFI variable through systemd)
- **System updates from Steam:** Steam moves from `steamos-update` to a D-Bus
  API (`atomupd-manager`), which `io-steamos-manager` could serve with
  `xbps-install -Su` behind it
- **A factory reset of Io's own** (fresh home directory): a design decision,
  and destructive
- **Live ISO with an installer**, once self-built void-mklive ISOs boot
  (they drop to dracut's emergency shell, cause not found yet); after it, **flavours**: *Plasma* (today's image),
  *Base* (game mode only), *Slim* (a light desktop). The split is prepared:
  `io-base` is the core, `io-desktop` adds the desktop
- **For 1.0:** SSH off in images, as on SteamOS; a way to replace the
  default password on first boot. 1.0 is the beta (`beta1.img`,
  `beta1.iso`)

---

## Recurring

- `pkgcheck.sh`: Valve's package versions against Io's
- Valve's kernel updates
- Boot logs, for regressions and new warnings
- After each gamescope update: *Use Legacy X11* in Steam's developer
  settings
