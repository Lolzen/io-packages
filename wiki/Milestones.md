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

- *Tests pending* and *Open observations* below
- Valve's newer versions (*Catching up with Valve*)
- Void's side: Mesa patches dropped as Void's Mesa takes them (the three
  RADV fixes went with 26.2.6), wpa_supplicant's rescan patches with
  the next hostap release, and the overlays rebuilt after Void updates
  (*Recurring*)
- *Polish* below

---

## In branches

Work that is built but not on `main` yet: nothing at the moment.

---

## Next (no theme yet)

Nothing scheduled. SteamOS Manager's runit support stays Io's own: Valve
declined it (2026-10-31, issue 32 on Valve's GitLab: shipping what they do
not test would cost every release time, for a niche case). The seven
commits live in the branch `runit` of
[Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager) and
are rebased onto each Valve update (*Recurring*).

---

## Open observations

- **Touch only with the dock on SteamOS:** SteamOS switches the trackpads
  off while the dock is attached; Io does not (see [Deviations](Deviations))
- **`€` from Steam's keyboard in the desktop** does not arrive (the AltGr
  level); German letters and emoji do. On SteamOS 3.9.2 the keyboard
  typed no umlauts or ß in the desktop at all (2026-10-04, see
  [Deviations](Deviations)); `€` was not checked there, and no longer can
  be: the Deck runs only Io since 2026-10-31
- **Controller navigation dead after boot** until the Steam button is
  pressed, now and then: Steam logs "Prevented loading a mapping that's
  being deleted" in `console_log.txt` at start, and only in those boots.
  The same line is in SteamOS's logs of a boot that hung the same way, so
  it is Steam's (Steam Input at start); reported as
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921),
  with the client builds it happened with. Not seen yet with client
  1793235415 (first boots, 2026-10-29); the entry goes when the issue is
  fixed

---

## Tests pending

Postponed (2026-10-28), not dropped.

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
  `modules-reload.sh` (reloading ath11k around hibernation) is not needed:
  the Deck does not hibernate (`jupiter-hibernate-disable`)
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
- **A misdetected SanDisk microSD card** (named `SD032`, 30.6 MB): Valve's
  rescan rule runs through `io-detach` now; checked with `udevadm test`
  that a normal card is left alone and still mounts
- **Other handhelds** (Legion Go, ROG Ally, MSI Claw, Zotac Zone):
  steamos-manager brings Valve's device files for them, but Io is not
  built for them (no InputPlumber for their controllers) and nothing is
  tested

---

## Polish

- Boot splash: done 2026-11-05 (`io-branding` 0.4.1: the still logo at
  boot, kept on screen until game mode by `plymouth-holo`; the animated
  *Io Torus* during firmware updates). On the Deck the simulated update's
  animation seemed hidden behind the logo; harmless, to look at with the
  next real update
- Plasma: messages when switching modes, Valve's nested desktop (Plasma
  inside game mode; a first try with Valve's files: logging out of it did
  not end its session)

---

## Later milestones

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
  support; on 2026-10-28 Valve's main of 2026-10-24); on 2026-10-27
  `jupiter-hibernate-disable` 0.1 (no hibernation on the Deck),
  `steamdeck-dsp` 1.03 and gamescope 3.17.0 (Void's, with Io's 32-bit WSI
  layer). Checked on 2026-10-27 and not needed:
  `steamos-customizations-jupiter` 20260916.1 (A/B work and packaging
  splits), the `holo-*` renames (`holo-systemreport` 1.24,
  `holo-networking-tools` 1.4; `holo-networkmanager-config` 1.0 was taken
  on 2026-10-28 in place of Io's `steamos-networking-tools`),
  `atomupd-daemon` 0.20260907.1 (`Atomupd1` version 9 only adds
  credentials for custom updates). WirePlumber
  0.5.18 and PipeWire are Void's, newer than or equal to Valve's (Valve's
  loopback patches only rebased; its one new patch is for smart filters);
  Xwayland 24.1.14 still needs Io's overlay (the keysym patch is not in it)
  and follows when Void has it. Valve's Mesa on its main branch is what
  Io's overlay was checked against (RADV `steamos-26.05.19`; radeonsi
  26.1.2-4 only adds a virgl patch for virtual machines). Valve's `scx`
  (`1.1.3.linux.steamos.2`) is a snapshot of upstream main of September
  2026 plus 26 LAVD changes by its author that upstream does not have yet;
  LAVD is opt-in on the Deck (Steam offers no switch for it), so Io stays
  with Void's `scx` and takes them as Void updates (upstream 1.1.4 is out,
  Void has 1.1.3). SteamOS 3.9.4 and 3.9.5 (checked 2026-10-29 against
  their image manifests): nothing Io did not have; `jupiter-staging` and
  `holo-staging` have nothing newer. Of all Arch packages Valve rebuilds
  for 3.9.5, plymouth and Orca carry patches Io needs (overlays since
  2026-11-05);
  three fixes wait for their upstream release and Void: SDDM comparing its
  configuration's times in UTC (a session switch after a timezone change),
  PipeWire 1.6.11's Bluetooth fixes, gamescope blanking the screen before
  sleep. Mesa follows Void (26.2.6 since 2026-10-29). Valve's changes up to
  2026-11-04 (checked 2026-11-05): 67 pure rebuilds for Arch's LLVM 23 and
  OpenSSL 4; taken: the kernel (Io moved to 7.3, see [Kernel](Kernel), with
  the metapackage `linux-neptune`), SteamOS's `amdgpu.dcdebugmask=0x60000`
  (linear brightness), NetworkManager's ARP flux fix and jupiter-hw-support
  20261028.1's udisks messages; waiting: iwd's four security fixes (until
  Void or upstream has them), Plasma 6.8 (when Void has it; `kwin-holo`
  then keeps two patches). Comparisons are made
  against Valve's manifests and source archives: the Deck runs only Io
  since 2026-10-31, so there are no new SteamOS captures
- **Flavours:** *Plasma* (today's image), *Base* (game mode only), *Slim*
  (a light desktop). The split is prepared: `io-base` is the core,
  `io-desktop` adds the desktop
- **Automation:** done since 2026-10-31: the upstream check (GitHub
  Actions, every 8 hours: Valve's packages and release branches, the
  overlays against Void, the Void packages Io waits for, Valve's, Void's
  and kernel.org's kernels, SteamOS Manager against Valve's main; findings
  in one issue labelled `upstream-check`) and *Create next release*
  (version step, fresh images, release with notes; see
  [Building](Building)). Still open: GitHub Actions that build and publish
  the packages themselves; man pages
- **For 1.0:** SSH off in images, as on SteamOS; a way to replace the
  default password on first boot; a sweep of Io's packages for Valve's
  artwork and trademarks (`steamdeck-kde-presets`' wallpapers, avatars and
  splash, the cursor in `deck-hw-support`); whether Valve's binaries
  (firmware, updaters, Steam's bootstrap) may be passed on. 1.0 is the
  first stable release

---

## Recurring

- The upstream check's issue (`upstream-check`): each finding taken or
  decided; `./pkgcheck.sh` and committing `docs/` clears Valve's package
  findings, `ci/void-watch.txt` lists what Io waits for in Void
- SteamOS Manager: Io's seven runit commits rebased onto Valve's update,
  every commit built (`cargo check --all-targets`), tests, fmt and clippy
  on the result, then pushed to the fork's `runit` and the template raised
  (version: 26.4.1 with the date of Valve's newest commit)
- After Void updates: `./build.sh -p --overlays` (rebuilds what Void
  rebuilt; stops for a review when Void moved to a new version), see
  [Building](Building)
- Valve's kernel updates, with the configuration review described on
  [Kernel](Kernel); Valve's first 7.3 tag replaces Io's port of the
  integration branch
- Boot logs, for regressions and new warnings
