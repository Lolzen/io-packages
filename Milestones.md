# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog).

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

- **Relogin after a crashed session takes 20–30 s.** Valve sets
  `KillUserProcesses=True` (`jupiter-legacy-support`), so logging out ends
  every process of the user; Io does not. Now that session switches are
  real logouts, check whether leftover processes are the delay
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

---

## Polish

- Designed boot splash; the black gap while Steam loads inside gamescope
- Plasma: messages when switching modes, the notification service requested
  in game mode, Valve's nested desktop (Plasma inside game mode)

---

## Small items

- `holo-sudo`: Valve's sudoers files, above all `no-fqdn` (sudo does not
  hang resolving the host name without a network)
- `holo-realtek-firmware-toggles`: only for Realtek USB Wi-Fi sticks
- `steamos-devkit-service`: DNS-SD through Avahi instead of
  systemd-resolved
- `jupiter-firewall`: a decision first — Io has no firewall
- `cecd`/`cec-audio-control`: needs a dock to test
- `steam-web-debug-portforward`: CEF debugging in developer mode
- `io-steamos-manager` interfaces without a counterpart yet:
  `ScreenReader`, `LowPowerMode1`, `Audio1`, `WifiDebug1`

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
- **Live ISO with an installer**, once void-mklive handles dracut 112's
  live-boot changes; after it, **flavours**: *Plasma* (today's image),
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
- When Void's gamescope reaches 3.16.22: screen recording works on a stock
  image
