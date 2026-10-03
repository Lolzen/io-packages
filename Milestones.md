# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 5](Alpha-5); what has
changed since is on [Alpha 6](Alpha-6).

---

## Alpha 6 (in progress, theme not chosen yet)

What has changed since Alpha 5 is on [Alpha 6](Alpha-6).

**Decided (2026-10-03):**

- Valve's Mesa: not ported, Io stays with Void's Mesa (see
  [Deviations](Deviations), *Graphics*)
- VRAM priority for the foreground game: not implemented (see
  [Deviations](Deviations), *Not present on Io*)
- `lib32-gamescope`: done, as `gamescope-wsi-32bit`

**Next: a last SteamOS reference round**, before the NVMe is wiped: a full
capture with Steam's stable and beta client (environment, D-Bus calls per
step, configuration, firmware checksums), a guided test run on SteamOS, and
an image of SteamOS's root partition as a lasting reference. Then the
findings below are evaluated one by one, and a plan for Alpha 6 is made
from them.

**Candidates from the analysis of 2026-10-03:**

- **Bluetooth firmware:** Valve's `rtl8822cu_fw.bin` and
  `rtl8822cu_config.bin` in `/usr/lib/firmware/updates/` (wake-on-Bluetooth;
  check dmesg first), and Valve's older `vangogh_vcn.bin` instead of the one
  AMD withdrew
- **`cecd` 0.3.0** (TV standby on suspend, protocol fixes); optionally
  `HdmiCec2` in `io-steamos-manager`, through cecd's own D-Bus settings
- **Proton nice limit** back, at Valve's corrected path
- **Kernel 7.2.7.valve1**, together with the decision on the configuration
  base ([Kernel](Kernel))
- **Small updates:** `gpu-trace` 2.16, `holo-realtek-firmware-toggles` 1.3-3
- **`io-steamos-manager`:** `SwitchToDesktopSession` (new in Steam), drop
  `Audio1` (removed by Valve)
- **System updates from Steam** through a real `steamos-update` with xbps
  behind it (see [Helper status](Helper-Status)); the largest item and a
  possible theme
- **Packages not evaluated yet:** the list on
  [SteamOS packages](Valve-Package-Survey) (*Not evaluated yet*)

---

## Open observations

- **Roaming** between router and repeater with the same network name: the
  Deck held on to the weak connection (seen with iwd, before
  `wireless-regdb`). Compare with wpa_supplicant; Valve's
  `wireless-domain-setter` (not evaluated yet) may belong here
- **Steam's developer settings:** *Use Legacy X11 Desktop Mode* is missing
  because Io reports one desktop session (cause found, see
  [Deviations](Deviations)); *Speaker Test* does nothing and looks like a
  placeholder in Steam (compare on SteamOS)
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
- **Wake-on-Bluetooth** (a controller waking the Deck from suspend), on
  SteamOS and on Io, before and after Valve's Bluetooth firmware
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
- **Installing to the internal NVMe**, once SteamOS on it is no longer needed
  as the reference, with the recovery stick (built and booting; its
  installer is tested with this move, see [Installation](Installation));
  suspend-then-hibernate comes with it (Valve's resume path keeps the swap
  file's position in an EFI variable through systemd; Valve's newer
  configuration allows suspend-then-hibernate again, 20 minutes on battery)
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
- **System updates from Steam:** see the Alpha 6 candidates above
- **A factory reset of Io's own** (fresh home directory): a design decision,
  and destructive
- **Live ISO with an installer**, once self-built void-mklive ISOs boot
  (they drop to dracut's emergency shell, cause not found yet); the
  recovery stick covers installing in the meantime. After it,
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
