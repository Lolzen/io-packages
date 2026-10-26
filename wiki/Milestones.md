# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Beta 0.8](Beta-0.8).

---

## Beta

Beta 0.8 (October 2026) is the first beta release: Io on the internal SSD,
Valve's own SteamOS Manager, and the parts that needed the NVMe tested. The
beta is for making Io good. Its release versions go on from there: 0.0.1
steps for ordinary releases (0.8.1, 0.8.2, ...), a 0.1 step for a larger
change (0.9, ...; the middle number goes on past 9, as in 0.10 or
0.102.3). 1.0 is the first stable release. SSH stays enabled in the images
throughout the beta. Whether a beta release comes with a new image is
decided per release. io-packages is public, but there is no call for
testers yet.

**Release by release**

- Pull request #1 (Io's changelog in Steam's patch notes): the check of
  Steam's update page
- *Tests pending* and *Open observations* below
- Valve's newer versions (*Catching up with Valve*)
- Void's side: Mesa patches dropped as Void's Mesa takes them (the three
  RADV fixes most likely with 26.2.6), wpa_supplicant's rescan patches with
  the next hostap release, gamescope 3.17 once Void has it (Io's
  `gamescope-wsi-32bit` follows it), and the overlays rebuilt after Void
  updates (*Recurring*)
- *Polish* below

---

## In branches

Work that is built but not on `main` yet:

- **Pull request #1** (`codex/io-cef-changelog`): Io's own changelog in
  Steam's patch notes for system updates

---

## Next (no theme yet)

- **SteamOS Manager's runit support at Valve:** offered on Valve's GitLab
  (2026-10-23), in the issue, with the fork's branch `runit`
  ([Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager)) and
  the commits as patches; Valve's GitLab does not let the account fork, so
  there is no merge request yet. Waiting for Valve's answer; changes Valve
  asks for, or bugs in Io's use of it, go into the branch
- **Valve's SD card rescan rule** (`99-sdcard-rescan.rules`, a workaround
  for misdetected SanDisk microSD cards): disabled so far, since it starts
  its script with `systemd-run` and had nothing to do while Io booted from
  the card. With Io on the internal SSD it matters; it needs `io-detach` in
  place of `systemd-run`
- **The recovery stick as a release download:** installing on the internal
  SSD and *Repair Io* are tested, but `recovery.img` is not attached to the
  releases yet; it is built with `build/mkrecovery.sh` (see
  [Building](Building))

---

## Open observations

- **Desktop responsiveness:** SteamOS 3.9.2's desktop felt more responsive
  than Io's. Compared on 2026-10-04: the main difference is the disk (Io on
  the SD card: random reads about 3 ms, SteamOS on the NVMe 0.12 ms); kwin's
  missing realtime threads are fixed in Alpha 6. Same scheduler, governor
  and preemption. To check again now that Io runs from the NVMe
- **vpower's shutdown at 0.5 %:** never tested on a real empty battery
- **Screen sharing prompt for a new user:** Io asks once when Steam starts
  in the desktop (Plasma's *Share screen with*, fresh user after Io's
  factory reset, 2026-10-20); SteamOS 3.9.3 does not (fresh user,
  2026-10-19). Not a dock matter on either. Most likely a screencast
  package that comes with Io's kwin/Plasma and that SteamOS does not ship.
  Suppressing it comes later
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

- **The image build** with `/dev`, `/proc` and `/sys` mounted during the
  package install (`build/common.sh`, as void-mklive): Python's
  byte-compiling (`compileall -j0`) failed for some modules without them.
  Check at the next `mkrootfs.sh --clean` that those errors are gone and
  nothing stays mounted
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
- **The LAVD scheduler under Valve's steamos-manager:** choose it in
  Steam, then `sv status scx` (run); back to none (down)
- **Steam's factory reset with `io-factory-reset` 0.2.1_3:** afterwards
  `scx` and `ec-log` are still linked with their `down` file, and LAVD can
  be chosen (`io-reset-check.sh`, project tools). Before 0.2.1_3 the reset
  unlinked them. A fix to the reset cannot be tried through the testing
  channel: the reset's OS part installs the default channel's version
  first
- **Steam's experimental SteamRT3 client** on Io: a capture with
  `io-rt3-capture.sh` (package `io-testsuite`, branch `testsuite`)
- **Drives in Steam:** a drive that already carries a Steam library (Steam
  should take it over), and ejecting a drive from Steam
- **Decky Loader**
- **SteamOS Devkit Client:** pairing and deploying (the service answers and
  is visible on mDNS)
- **Wake-on-Bluetooth** (a controller waking the Deck from suspend). Io
  logs "wake-on-bluetooth enabled" with Void's and with Valve's firmware
  (Valve's is in place since Alpha 6); a real wake is untested
- **bluez-holo's fixes** with the hardware they are for: a Steam Controller
  across suspend, a Switch Pro Controller

---

## Needs hardware to test

Parts that are in Io but cannot be tested without hardware Georg does not
have; they need someone with the hardware.

- **Valve's Docking Station:** its firmware updater (Valve's
  `jupiter-dock-updater-bin`, with the real `--check` and `UpdateDock1`),
  and HDMI-CEC with a dock that passes it through (`/dev/cec*`; Georg's
  JSAUX dock does not, on SteamOS neither); cecd 0.3.0 and Steam's CEC
  switches (`HdmiCec2`) work, the TV side is untested
- **Steam Deck OLED:** Valve's packages and settings for it are in place:
  Valve's audio profile differences and SOF firmware, the mura correction
  (`galileo-mura`), the 45–90 Hz refresh range and HDR default, Wi-Fi debug
  mode (`trace-cmd`), the regulatory domain of its ath11k card. The kernel
  (Valve's tree) and fan control already covered it. Valve's
  `modules-reload.sh` (reloading ath11k around hibernation) is not ported
- **Steam Machine:** EC logging (`FirmwareDebug1`, `ec-log`), waking from
  the TV through the embedded controller (steamos-manager), Valve's audio
  profile (HDMI, AC3 for ARC), fan control. Not ported: CEC volume control
  (needs Valve's PipeWire and WirePlumber patches), Valve's PipeWire HDMI
  fixes (ports for the AC3 profiles, the HDMI profiles rechecked when the
  connected display's ELD changes; from PipeWire's master, not in the 1.6
  series Void ships), BIOS updates (`fremont-hw-support`, fwupd), Valve's
  own USB Bluetooth firmware. The PipeWire fixes wait for a Void PipeWire
  update that contains them, rather than an Io overlay, unless a Steam
  Machine user needs them sooner
- **Other handhelds** (Legion Go, ROG Ally, MSI Claw, Zotac Zone):
  steamos-manager brings Valve's device files for them, but Io is not
  built for them (no InputPlumber for their controllers) and nothing is
  tested

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
  work as on SteamOS (tested 2026-10-19, at boot and from Steam), and the
  update at boot with its splash (title, log lines, progress) runs through
  with Valve's simulated controller update (`/etc/.simulate-firmware-update`,
  2026-10-20). Still to test: a real controller update once Valve ships
  newer firmware, a BIOS update last, if at all. Open: whether Valve's
  binaries (BIOS images, `h2offt`, controller firmware) may be
  redistributed in Io's repository
- **Catching up with Valve, periodically:** after Io's beta, a regular
  review round against SteamOS and Valve's newest packages; in the long run
  Void's own packages wherever Valve's patches have gone upstream. Done
  once for 3.9.2 in October 2026; from SteamOS 3.9.3 (October 2026) Io has
  `gpu-trace` 2.17, `holo-realtek-firmware-toggles` 1.4 and iwd's new band
  scanning patch, `jupiter-hw-support` 20260930.1's firmware updaters and
  the kernel `7.2.7-valve2` (as 7.2.11); from Valve's main branch
  (2026-10-21) kwin 6.7.3-1.7's suspend patches and wpa_supplicant
  2.12-1.3's rescan patches as merged in hostap, and Valve's steamos-manager
  itself from its main branch after 26.4.1 (2026-10-22, with Io's runit
  support). Valve's versions newer
  than Io's, seen on 2026-10-12 and not taken yet:
  `steamos-customizations-jupiter` 20260916.1, `holo-networking-tools` 1.4,
  `holo-systemreport` 1.24, PipeWire 1.6.8,
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
