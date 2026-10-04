# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 5](Alpha-5); what has
changed since is on [Alpha 6](Alpha-6).

---

## Alpha 6 (in progress)

What has changed since Alpha 5 is on [Alpha 6](Alpha-6). The plan (draft,
proposed theme *SteamOS 3.9.2 parity*) is kept in the project's working
notes and comes here once Georg confirms it.

**Decided:**

- The reference is now **SteamOS 3.9.2** (2026-10-04; before 3.8.4). Io's
  ported packages already match it, apart from the updates below
- Valve's Mesa: not ported, Io stays with Void's Mesa (see
  [Deviations](Deviations), *Graphics*)
- VRAM priority for the foreground game: not implemented (see
  [Deviations](Deviations), *Not present on Io*)
- `lib32-gamescope`: done, as `gamescope-wsi-32bit`
- Input methods for Steam's keyboard (Chinese, Japanese, Korean): yes, for
  completeness

**Done:** the SteamOS reference round (capture of 3.9.2 with the Steam beta
client, guided test run with D-Bus per step) and the evaluation of the
Valve packages Io did not track ([SteamOS packages](Valve-Package-Survey);
a few not installed on SteamOS are still open).

**Planned, by phase:**

- **Checks on Io first:** GPU performance level after Steam starts,
  Bluetooth firmware log, emoji font, Proton nice limit, transparent huge
  pages, three sysctls Void sets differently, desktop responsiveness
  (SteamOS's desktop felt faster), Steam's keyboard in the desktop with a
  German layout
- **Fixes:** a probable `io-steamos-manager` bug (setting the manual GPU
  clock switches the GPU to manual itself; Valve refuses outside manual
  mode, so Io likely stays at a fixed 1600 MHz after every Steam start);
  `steamos-select-branch -c` answers `rel`; the game mode session as
  Valve's 3.9.2 script (see [Deviations](Deviations)); the Proton nice
  limit; two sysctls; `Audio1` removed; Valve's Bluetooth settings
- **Updates to 3.9.2:** `cecd` 0.3.0, `gpu-trace` 2.16,
  `holo-realtek-firmware-toggles` 1.3-3, `steamos-networking-tools` 1.3,
  kernel 7.2.7 with the configuration base ([Kernel](Kernel)), an add-on
  package with Valve's Bluetooth firmware and the older `vangogh_vcn.bin`
- **`io-steamos-manager`:** `HdmiCec2` (Steam's CEC switches use it),
  `SwitchToDesktopSession`, the fan in download mode
- **Input and desktop:** input methods, `plasma-keyboard` instead of
  Maliit, a colour emoji font, the desktop keeping game mode's brightness,
  mangoapp's frame pacing
- **System updates from Steam** through a real `steamos-update` with xbps
  behind it (see [Helper status](Helper-Status)); the largest item, may
  move to Alpha 7

**Also open:** a capture with Steam's experimental SteamRT3 client; a
collection directory for Valve's patches against Void's packages (no build
integration yet).

---

## Open observations

- **Roaming** between router and repeater with the same network name: the
  Deck held on to the weak connection (seen with iwd, before
  `wireless-regdb`). Compare with wpa_supplicant; note that Void builds
  `wpa_supplicant` without the roaming features Arch enables (WNM, MBO)
- **Desktop responsiveness:** SteamOS 3.9.2's desktop felt more responsive
  than Io's; to compare
- **Screen sharing prompt in the desktop:** Steam asks Plasma's portal for
  screen sharing at start; the prompt appears until *Allow restoring* is
  chosen once. SteamOS 3.9.2 does the same calls (ScreenCast session, then
  a permission stored); what a new user sees there is still unchecked
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
- **Catching up with Valve, periodically:** after Io's beta, a regular
  review round against SteamOS and Valve's newest packages; in the long run
  Void's own packages wherever Valve's patches have gone upstream. Done
  once for 3.9.2 in October 2026
- **System updates from Steam:** see Alpha 6 above
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
