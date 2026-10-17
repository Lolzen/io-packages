# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 7](Alpha-7).

---

## In branches

Work that is built but not on `main` yet, each on its own branch of
io-packages:

- **`destructive`:** what the move to the NVMe needs and can only be tested
  with it: formatting drives from Steam, the firmware updaters (BIOS,
  controller, dock), suspend-then-hibernate, *Repair Io*'s tools on the
  recovery stick, and a factory reset of Io's own. None of it is tested on
  hardware yet; Valve's calibration tools follow once it is merged
- **Pull request #1** (`codex/io-cef-changelog`): Io's own changelog in
  Steam's patch notes for system updates
- **Pull requests #2, #3 and #4:** the Steam Deck OLED (`galileo-oled`),
  other handhelds with a Valve device file (`other-devices`) and the Steam
  Machine (`steam-machine`); they need the hardware to be tested (see
  *Needs hardware to test*)
- **`test-nested-desktop`:** Valve's nested desktop (Plasma inside game
  mode); logging out of it does not end its session yet

---

## Next (no theme yet)

- **NetworkManager 1.58.1** for `NetworkManager-holo`, once Void's update
  (void-packages pull request 62975) is merged; Valve's patch applies to it

- **TOMOYO** activated by Void's `/sbin/init`, with the next kernel update
- **steamos-manager refuses calls from games:** on Valve's main branch
  after 26.4.1 (not in SteamOS 3.9.2), the session half rejects D-Bus calls
  whose sender runs inside a game, recognised by the systemd cgroup
  `/app-steam-app…` Steam starts games in. Io has no such cgroups, so it
  needs its own way to tell a game's process; a larger change that can only
  partly be tested. Left until Valve ships it

---

## Open observations

- **Desktop responsiveness:** SteamOS 3.9.2's desktop felt more responsive
  than Io's. Compared on 2026-10-04: the main difference is the disk (Io on
  the SD card: random reads about 3 ms, SteamOS on the NVMe 0.12 ms); kwin's
  missing realtime threads are fixed in Alpha 6. Same scheduler, governor
  and preemption. To check again after the move to the NVMe
- **vpower's shutdown at 0.5 %:** never tested on a real empty battery
- **Wi-Fi next to the dock's Ethernet showed "can't reach network"** once,
  during a day of heavy testing; plugging and unplugging the dock later
  behaved correctly. If it comes back, record before reconnecting:
  `nmcli -f DEVICE,STATE,IP4-CONNECTIVITY device; nmcli -f CONNECTIVITY
  general; ip route`
- **Touch only with the dock on SteamOS:** SteamOS switches the trackpads
  off while the dock is attached; Io does not (see [Deviations](Deviations))
- **`€` from Steam's keyboard in the desktop** does not arrive (the AltGr
  level); German letters and emoji do. On SteamOS 3.9.2 the keyboard
  typed no umlauts or ß in the desktop at all (2026-10-04, see
  [Deviations](Deviations)); `€` there is not checked
- **Controller navigation dead after boot** until the Steam button is
  pressed, now and then: Steam logs "Prevented loading a mapping that's
  being deleted" in `console_log.txt` at start, and only in those boots.
  The same line is in SteamOS's logs of a boot that hung the same way, so
  it is Steam's (Steam Input at start); reported as
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921)
- **Steam hung in its boot animation** on the first start after switching
  to the beta client (the bootstrapper had installed the update;
  steamwebhelper logged "SteamClient globals not available" and a
  timeout waiting for `RegisterForStartupFinished`). A reboot fixed it.
  If it happens again, copy the logs in `~/.local/share/Steam/logs`
  (`bootstrap_log.txt`, `console_log.txt`, `cef_log.txt`,
  `webhelper.txt`, `webhelper_js.txt`) over SSH before restarting

---

## Tests pending

- **Steam's experimental SteamRT3 client** on Io: a capture with
  `io-rt3-capture.sh` (package `io-testsuite`, branch `testsuite`)
- **Drives in Steam:** a drive that already carries a Steam library (Steam
  should take it over), and ejecting a drive from Steam
- **Decky Loader**
- **Screen sharing prompt for a new user:** set
  `~/.local/share/flatpak/db/screencast` aside, reboot, switch to the
  desktop: Steam should ask once and, with *Allow restoring*, never again
  (as on SteamOS, which grants nothing in advance either)
- **SteamOS Devkit Client:** pairing and deploying (the service answers and
  is visible on mDNS)
- **Wake-on-Bluetooth** (a controller waking the Deck from suspend). Io
  logs "wake-on-bluetooth enabled" with Void's and with Valve's firmware
  (Valve's is in place since Alpha 6); a real wake is untested
- **bluez-holo's fixes** with the hardware they are for: a Steam Controller
  across suspend, a Switch Pro Controller

---

## Needs hardware to test

Parts that can be built, but not tested without hardware Georg does not
have. They are to become issues and draft pull requests, marked as needing
someone with the hardware.

- **Valve's Docking Station:** its firmware updater (`hub_update`, today a
  stub that reports "up to date"), and HDMI-CEC with a dock that passes it
  through (`/dev/cec*`; Georg's JSAUX dock does not, on SteamOS neither);
  cecd 0.3.0 and Steam's CEC switches (`HdmiCec2`) work, the TV side is
  untested
- **Steam Deck OLED:** Io is built for the LCD model; the OLED needs its own
  Wi-Fi driver path (ath11k), Valve's Galileo audio profile and firmware,
  and the display quirks

---

## Polish

- Designed boot splash
- Plasma: messages when switching modes, Valve's nested desktop (Plasma
  inside game mode, see *In branches*)

---

## Later milestones

- **Kernel metapackage** `linux-neptune`, with the next kernel update
- **Installing to the internal NVMe**, once SteamOS on it is no longer needed
  as the reference, with the recovery stick (built and booting; its
  installer is tested with this move, see [Installation](Installation));
  suspend-then-hibernate comes with it (Valve's resume path keeps the swap
  file's position in an EFI variable through systemd; Valve's newer
  configuration allows suspend-then-hibernate again, 20 minutes on battery;
  Io's version is on the branch `destructive`, see *In branches*)
- **Formatting drives from Steam** (from Alpha 5): Valve's `format-device.sh`
  is in place with Io's check against formatting the disk Io runs from;
  on `main`, `FormatDevice` and the format helpers still refuse, the branch
  `destructive` has them working. Tested together with
  the move to the NVMe: first against the internal SSD while Io runs from
  the card (its SteamOS is wiped then anyway; Valve's device list must
  refuse it), then, with Io on the NVMe, against SD cards and USB drives
- **Firmware updaters** (from Alpha 5): on the branch `destructive`,
  Valve's BIOS, controller and dock updaters with their check modes, so
  Steam can show whether an update is due; flashing is tested last, if at
  all. Until then SteamOS on the same Deck keeps the firmware current
- **Catching up with Valve, periodically:** after Io's beta, a regular
  review round against SteamOS and Valve's newest packages; in the long run
  Void's own packages wherever Valve's patches have gone upstream. Done
  once for 3.9.2 in October 2026. Valve's versions newer than Io's, seen on
  2026-10-12 and not taken yet: `jupiter-hw-support` 20260930.1, `gpu-trace`
  2.17, `linux-neptune-72` 7.2.7-valve2, `steamos-customizations-jupiter`
  20260916.1, `holo-networking-tools` 1.4, `holo-systemreport` 1.24,
  steamos-manager 26.4.1-3, NetworkManager 1.58.0, PipeWire 1.6.8,
  WirePlumber 0.5.18, `atomupd-daemon` 0.20260907.1 (`Atomupd1` version 9)
- **Repair Io** on the recovery stick: in this release a placeholder that
  lists the disks ([Installation](Installation)); `io-repair` on the
  branch `destructive` checks the file system and repairs the initramfs,
  the boot loader, hibernation and the packages
- **A factory reset of Io's own**, as Steam offers it (user data, the
  system, or both): on the branch `destructive`, to be compared with
  SteamOS's own reset, which is recorded when SteamOS is wiped
- **Live ISO with an installer**, once self-built void-mklive ISOs boot
  (they drop to dracut's emergency shell, cause not found yet); the
  recovery stick covers installing in the meantime. After it,
  **flavours**: *Plasma* (today's image),
  *Base* (game mode only), *Slim* (a light desktop). The split is prepared:
  `io-base` is the core, `io-desktop` adds the desktop
- **Automation, once Io changes less often:** GitHub Actions that build and
  publish the packages; man pages; a version check that writes Valve's
  newer versions to a file unless they are listed as already looked at
  (`pkgcheck.sh` today reports what changed since its last run)
- **For 1.0:** SSH off in images, as on SteamOS; a way to replace the
  default password on first boot; a sweep of Io's packages for Valve's
  artwork and trademarks (`steamdeck-kde-presets`' wallpapers, avatars and
  splash, the cursor in `deck-hw-support`). 1.0 is the beta (`beta1.img`,
  `beta1.iso`)

---

## Recurring

- `pkgcheck.sh`: Valve's package versions against Io's
- After Void updates: `./build.sh -p --overlays` (rebuilds what Void
  rebuilt; stops for a review when Void moved to a new version), see
  [Building](Building)
- Valve's kernel updates, with the configuration review described on
  [Kernel](Kernel)
- Boot logs, for regressions and new warnings
- After each gamescope update: *Use Legacy X11* in Steam's developer
  settings
