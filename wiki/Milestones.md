# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 6](Alpha-6); what
has changed since is on [Alpha 7](Alpha-7).

---

## Alpha 7 (in progress)

- **Done:** *Restart* from Io starts Io again (`io-base` 0.6.0); GRUB
  boots without its menu (`io-base` 0.7.0); the image scripts bring the
  repository keys along; Steam's keyboard in the desktop, the brightness
  through Valve's kwin patch and no black flash when returning to game mode
  (`kwin-holo`, `xorg-server-xwayland-holo`); Valve's Wi-Fi fixes (`wpa_supplicant-holo`,
  `iwd-holo`); Twemoji. See [Alpha 7](Alpha-7)
- **Checked against SteamOS:** `zenity` (same behaviour, no `zenity-gtk3`
  needed), `inputattach-cec-units` (no USB-CEC adapter, not needed),
  Steam's patch notes for updates (Valve's; they stay, see
  [Deviations](Deviations)), the screen sharing prompt (the permission
  store looks as on SteamOS apart from the app ID; a fresh user is still to
  be tried, see *Tests pending*), the question before switching to the
  desktop (comes with Steam's beta client)
- **Decided:** `void-artwork` stays (`plymouth-data` depends on it)
- **Open:** a capture with Steam's experimental SteamRT3 client

---

## Next (no theme yet)

- **Valve's Mesa as an overlay** ([overlay/README.md](https://github.com/Lolzen/io-packages/blob/main/overlay/README.md)):
  looked at again on 2026-10-11 (the OpenGL frame limiter applies to
  Void's 26.2.4, 6 of Valve's 14 RADV patches do not); to revisit with
  Void's next Mesa update
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
- **Steam hung in its boot animation** on the first start after switching
  to the beta client (the bootstrapper had installed the update;
  steamwebhelper logged "SteamClient globals not available" and a
  timeout waiting for `RegisterForStartupFinished`). A reboot fixed it.
  If it happens again, copy the logs in `~/.local/share/Steam/logs`
  (`bootstrap_log.txt`, `console_log.txt`, `cef_log.txt`,
  `webhelper.txt`, `webhelper_js.txt`) over SSH before restarting

---

## Tests pending

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

- **Valve's Docking Station:** its firmware updater (`hub_update`, Valve's
  package on the branch `destructive`), and HDMI-CEC with a dock that passes it
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
  inside game mode)

---

## Later milestones

- **Kernel metapackage** `linux-neptune`, with the next kernel update
- **Installing to the internal NVMe**, once SteamOS on it is no longer needed
  as the reference, with the recovery stick (built and booting; its
  installer is tested with this move, see [Installation](Installation));
  suspend-then-hibernate is tested with it (implemented on the branch
  `destructive`: Valve's settings and swap helper, Io's sleep hook writes
  the image location to an EFI variable of its own, the dracut module
  `io-resume` reads it; see [Deviations](Deviations))
- **Formatting drives from Steam** (implemented on the branch
  `destructive`): Valve's helpers and `format-device.sh` with Io's check
  against formatting the disk Io runs from, `FormatDevice` as a job. Tested
  together with the move to the NVMe: first against the internal SSD while
  Io runs from the card (its SteamOS is wiped then anyway; Valve's device
  list must refuse it), then, with Io on the NVMe, against SD cards and USB
  drives
- **Firmware updaters** (implemented on the branch `destructive`): Valve's
  BIOS updater (`h2offt` and the BIOS images), controller updater and dock
  updater (`deck-firmware-updaters`, `jupiter-dock-updater-bin`), the
  helpers, `UpdateBios1`/`UpdateDock1` and the updates at boot. Test order:
  the check modes first (`jupiter-biosupdate check`,
  `jupiter-controller-update --check`, `jupiter-dock-updater --check`), then
  a controller update, a BIOS update last, if at all. Open: whether Valve's
  binaries (BIOS images, `h2offt`, `hub_update`, controller firmware) may be
  redistributed in Io's repository
- **Catching up with Valve, periodically:** after Io's beta, a regular
  review round against SteamOS and Valve's newest packages; in the long run
  Void's own packages wherever Valve's patches have gone upstream. Done
  once for 3.9.2 in October 2026
- **Repair Io** on the recovery stick (implemented on the branch
  `destructive`): filesystem check, initramfs, boot loader, forgetting a
  hibernated session that does not resume, package check, root shell.
  Tested with the move to the NVMe
- **A factory reset of Io's own** (fresh home directory): a design decision,
  and destructive
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
  default password on first boot. 1.0 is the beta (`beta1.img`,
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
