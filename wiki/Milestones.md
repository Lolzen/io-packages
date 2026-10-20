# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Alpha 7](Alpha-7).

---

## Beta (next)

With Alpha 7 the foundation is in place and Io is usable day to day; the
beta is for making it good. Its release versions go on from Alpha 7's 0.7:
0.0.1 steps for ordinary releases (0.7.1, 0.7.2, ...), a 0.1 step for a
larger change (0.8, ...; the middle number goes on past 9, as in 0.10 or
0.102.3). 1.0 is the first stable release. SSH stays enabled in the images
throughout the beta. Whether a beta release comes with a new image is
decided per release. As in the alpha phase, io-packages is public, but
there is no call for testers yet (not even for the hardware pull
requests).

**First: the move to the NVMe**

1. The last captures on SteamOS, among them its factory reset
   (`steamos-reset-capture.sh`); SteamOS is wiped afterwards (done
   2026-10-18)
2. The branch `destructive` on the Deck: formatting
   against the internal SSD while Io runs from the card, the move with the
   recovery stick, suspend-then-hibernate, formatting SD cards and USB
   drives, the firmware updaters' check modes, `io-repair`, Io's factory
   reset (compared with SteamOS's capture). Done 2026-10-19/20: formatting
   refused for the internal SSD, the move, hibernating and resuming,
   formatting SD cards and USB drives, the check modes, Repair Io, the
   factory reset from Steam
3. `destructive` to `main` (done 2026-10-20); Valve's calibration tools
   follow as their own pull request
4. With Io on the NVMe: the desktop responsiveness again (*Open
   observations*)

**Then, release by release**

- Pull request #1 (Io's changelog in Steam's patch notes): the check of
  Steam's update page
- *Tests pending* and *Open observations* below
- Valve's newer versions (*Catching up with Valve*): the kernel
  7.2.7-valve2 with its configuration review ([Kernel](Kernel))
- Void's side: NetworkManager 1.58.1 (*Next*), Mesa patches dropped as
  Void's Mesa takes them (the three RADV fixes most likely with 26.2.6), and
  the overlays rebuilt after Void updates (*Recurring*)
- The image build: Python's byte-compiling fails for some modules because
  `mkrootfs.sh` installs the packages before `/dev` is mounted in the root
  (`compileall -j0` needs `/dev/shm`); mount the pseudo file systems first,
  as void-mklive does
- *Polish* below

---

## In branches

Work that is built but not on `main` yet, each on its own branch of
io-packages:

- **`dock-fw`** (pull request #6): Valve's dock firmware updater with
  Steam's real dock check and `UpdateDock1`; needs Valve's Docking Station
  to be tested
- **Pull request #1** (`codex/io-cef-changelog`): Io's own changelog in
  Steam's patch notes for system updates
- **Pull requests #2, #3 and #4:** the Steam Deck OLED (`galileo-oled`),
  other handhelds with a Valve device file (`other-devices`) and the Steam
  Machine (`steam-machine`); they need the hardware to be tested (see
  *Needs hardware to test*)

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

- **Hibernation from the desktop** (Io on the NVMe): Plasma's leave menu
  → *Hibernate* (the same path as `loginctl hibernate`, tested); Plasma's
  energy settings with suspend-then-hibernate: after 20 minutes of suspend
  the Deck should hibernate. elogind 252 tells a wake by its own timer from
  a wake by the user through the firmware's wake-up type, and the Deck's
  reads "power switch" (`/sys/firmware/dmi/entries/1-0/raw`, byte 24 =
  0x06): it may stay in suspend. `io-hibernate-test.sh check`/`logs`
  (project tools) record it
- **Wi-Fi after a long suspend:** once, after 32 minutes, the LCD's card
  (`rtw88_8822ce`) did not leave D3hot ("device inaccessible", "mac power
  on failed") and Wi-Fi stayed dead until a reboot; the suspend of two
  hours before resumed fine. If it comes back: restart NetworkManager,
  reload `rtw88_8822ce`, remove and rescan the PCI device, before
  rebooting, and compare with SteamOS (same kernel driver)
- **elogind at reboot:** since `elogind-holo` every reboot logs a segfault
  of elogind's reboot helper (`e-reboot`, same offset each time); the
  reboot itself happens. Check whether Void's `elogind` does the same
- **Steam's experimental SteamRT3 client** on Io: a capture with
  `io-rt3-capture.sh` (package `io-testsuite`, branch `testsuite`)
- **Drives in Steam:** a drive that already carries a Steam library (Steam
  should take it over), and ejecting a drive from Steam
- **Decky Loader**
- **Screen sharing prompt for a new user, at the dock** (the prompt
  comes with an external display; undocked, SteamOS 3.9.3 does not ask
  either): set `~/.local/share/flatpak/db/screencast` aside, reboot, switch
  to the desktop: Steam should ask once and, with *Allow restoring*, never again
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
  package with the real `--check` and `UpdateDock1`, on the branch
  `dock-fw` as a pull request), and HDMI-CEC with a dock that passes it
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
  inside game mode; a first try with Valve's files: logging out of it did
  not end its session)

---

## Later milestones

- **Kernel metapackage** `linux-neptune`, with the next kernel update
- **Firmware updates:** Valve's BIOS updater (`h2offt` and the BIOS
  images) and controller updater (`deck-firmware-updaters`), the helpers,
  `UpdateBios1` and the updates at boot are in place; their check modes
  work as on SteamOS (tested 2026-10-19, at boot and from Steam). Still to
  test: a controller update, a BIOS update last, if at all. Open: whether Valve's
  binaries (BIOS images, `h2offt`, controller firmware) may be
  redistributed in Io's repository
- **Catching up with Valve, periodically:** after Io's beta, a regular
  review round against SteamOS and Valve's newest packages; in the long run
  Void's own packages wherever Valve's patches have gone upstream. Done
  once for 3.9.2 in October 2026; from SteamOS 3.9.3 (October 2026) Io has
  `gpu-trace` 2.17, `holo-realtek-firmware-toggles` 1.4 and iwd's new band
  scanning patch, and `jupiter-hw-support` 20260930.1's firmware
  updaters. Valve's versions newer than Io's, seen on 2026-10-12 and
  not taken yet: `linux-neptune-72` 7.2.7-valve2, `steamos-customizations-jupiter`
  20260916.1, `holo-networking-tools` 1.4, `holo-systemreport` 1.24,
  steamos-manager 26.4.1-3, NetworkManager 1.58.0, PipeWire 1.6.8,
  WirePlumber 0.5.18, `atomupd-daemon` 0.20260907.1 (`Atomupd1` version 9)
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
  splash, the cursor in `deck-hw-support`); whether Valve's binaries
  (firmware, updaters, Steam's bootstrap) may be passed on. 1.0 is the
  first stable release

---

## Recurring

- `pkgcheck.sh`: Valve's package versions against Io's
- After Void updates: `./build.sh -p --overlays` (rebuilds what Void
  rebuilt; stops for a review when Void moved to a new version), see
  [Building](Building)
- Valve's kernel updates, with the configuration review described on
  [Kernel](Kernel)
- Boot logs, for regressions and new warnings
