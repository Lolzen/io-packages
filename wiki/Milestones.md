# Milestones

What is still open, and where it is headed. What each release brought is in
the [Changelog](Changelog). The latest release is [Beta 0.8.2](Beta-0.8.2).

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
commits are the patches of `srcpkgs/steamos-manager` (since 2026-11-11;
before that the branch `runit` of a fork) and are rebased onto each Valve
update (*Recurring*).

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
  animation seemed hidden behind the logo. In an X test bed (plymouthd
  with the same script and `plymouth-wrap`'s messages, 2026-11-11) the
  Torus runs on top of the logo and fades back, so the script's drawing
  order is not the cause; to look at on the Deck with the next update
  (`plymouthd --debug` in `97-io-firmware-update.sh`)
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
  credentials for custom updates). PipeWire is Void's (1.6.12 since
  2026-11-27, with the Bluetooth fixes of Valve's 3.9.5 build from 1.6.11);
  WirePlumber is Void's 0.5.19 with Valve's two backports for the mono
  audio switch (`wireplumber-holo` since 2026-11-27; Valve's loopback
  patches are Io's own script, its smart filter patch is in 0.5.19);
  Xwayland still needs Io's overlay (the keysym patch is not in 24.1.15
  either; `xorg-server-xwayland-holo` on Void's 24.1.14 since 2026-11-09,
  on 24.1.15 since 2026-11-25). Valve's Mesa on its main branch is what
  Io's overlay was checked against (RADV `steamos-26.05.19`, and since
  2026-11-18 `steamos-26.05.20`'s six commits: sparse binding through the
  kernel's `AMDGPU_GEM_VA2`; radeonsi
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
  three fixes waited for their upstream release and Void: SDDM comparing its
  configuration's times in UTC (a session switch after a timezone change),
  PipeWire 1.6.11's Bluetooth fixes (in Void's 1.6.12 since 2026-11-27),
  gamescope blanking the screen before sleep. Mesa follows Void (26.2.6 since 2026-10-29, 26.2.7 since
  2026-11-13). Valve's changes up to
  2026-11-04 (checked 2026-11-05): 67 pure rebuilds for Arch's LLVM 23 and
  OpenSSL 4; taken: the kernel (Io moved to 7.3, see [Kernel](Kernel), with
  the metapackage `linux-neptune`), SteamOS's `amdgpu.dcdebugmask=0x60000`
  (linear brightness), NetworkManager's ARP flux fix and jupiter-hw-support
  20261028.1's udisks messages; waiting: iwd's four security fixes (until
  Void or upstream has them), Plasma 6.8 (came with Void's 6.8.3 on
  2026-11-24). Valve's `holo-3.10` and `jupiter-3.10`
  (2026-11-06) start as copies of main; `pkgcheck.sh` watches 3.9 and
  3.10. Kernel 7.3.3 since 2026-11-08, 7.3.4 since 2026-11-11, Valve's
  7.3.1-valve1 (its first 7.3 release; the amdgpu explicit sync series is
  back, so `mesa-holo`'s `radv_vm_explicit_sync` works again) with 7.3.4
  since 2026-11-12, replacing Io's port; `7.3.1-valve2` (HDMI 2.1 for the
  Steam Machine) since 2026-11-14; bluez 5.88 (Void's, with Io's two
  patches, 2026-11-10). Valve's main of 2026-11-10: steamos-manager
  (`ds_inhibit` returns errors in fewer cases on shutdown), plasma-workspace 6.8.2-1.2 (a Qt virtual keyboard
  in the lock screen, where Steam's cannot show; taken with Plasma 6.8.3), `holo-3.9`'s gamescope 3.16.30.2 (backports of 3.17.0).
  Xwayland 24.1.15 (2026-11-10) fixes the X.Org advisory of that day
  (eight issues in the X server and Xwayland); Void has xorg-server
  21.1.26, Xwayland 24.1.15 since 2026-11-25, and Io's overlay follows
  Void.
  Valve's main of 2026-11-17: WirePlumber 0.5.18-1.4 (two upstream fixes,
  merged after 0.5.19: switching mono audio no longer drops streams; Io
  takes them with Void's next WirePlumber, `void-watch`) and holo's
  `lib32-zlib` 1.4 (Void has zlib 1.4). Valve's main of 2026-11-19:
  NetworkManager 1.58.1-3.4 (after resume, a full scan at once when the
  previous access point is not on its old frequency; taken),
  `holo-session-selection` 1.1 (session name `plasma-persistent`, Plasma's
  X11 session gone; taken in `io-session`), dock firmware
  V0.013.15.0.135 (`jupiter-dock-updater-bin` 20261116.01; taken, untested
  without Valve's dock); not needed: `linux-neptune-72` 7.2.15.valve1 (the
  fallback series, end of life), `atomupd-daemon` and
  `steamos-atomupd-client` 20261110 (Valve's update servers; Io has
  `io-atomupd`), `kcgroups` (needs systemd's slices), `holo-fs-offload`
  (`/nix`), RenderDoc 1.47 (not in Io), `scx-scheds` 1.1.4 (Io follows
  Void's `scx`, still 1.1.3), plasma-desktop 6.8.2-3 (lock screen part taken
  with Plasma 6.8.3). Valve's `7.3.1-valve3` (one HDMI
  2.1 patch reverted: FRL-capable TVs stayed dark in TMDS mode, Steam
  Machine) and stable 7.3.5 are not built: nothing for the Deck; they come
  with the next kernel that is (2026-11-27: Valve's `7.3.5-valve1` with
  stable 7.3.6, built on Georg's request, see [Kernel](Kernel)). Void's Plasma 6.8.3 (2026-11-23): `kwin-holo`
  on 6.8.3 with Valve's kwin 6.8.2-1.4 (brightness, Steam's keyboard past
  the input method, two input start-up fixes from kwin master); its other
  former patches (libei 1.6, small modes, the suspend fixes) and Valve's
  handheld default scale are in 6.8.3. `xdg-desktop-portal-kde-holo`
  rebased onto 6.8.3; new overlays `plasma-workspace-holo` and
  `plasma-desktop-holo` for the lock screen keyboard.
  Valve's changes of 2026-11-25 (checked that day): Void's Xwayland 24.1.15
  (X.Org's security fixes; `xorg-server-xwayland-holo` follows, the
  keysym patch unchanged); not needed: RADV `steamos-26.05.21` (two
  commits for a DCC fast clear bug of GFX11 and Strix only, plus a
  Monster Hunter Wilds entry; the Deck is GFX10.3), `linux-neptune-72`
  7.2.15.valve1-2 (the fallback series; Valve's neptune fragment no
  longer turns off `CONFIG_HYPERVISOR_GUEST`; 7.3's fragment still does),
  `jupiter-3.9`/`holo-3.9` (gamescope 3.16.30.2-2 with the screen-off
  before sleep commit `a962a4dc` that Io takes with a gamescope release,
  iwd 3.12-2.201 with the four security fixes Io takes from Void,
  `steamos-log-submitter` 0.8.4, `tzdata` 2026f, which Void has).
  Later that day: RADV `steamos-26.05.22` (two fixes for the batched
  sparse binding Io carries: unbinding a sparse range over 8 MiB on the
  Deck's GPU failed, and its zero pages were mapped without access flags;
  taken, `mesa-holo` 26.2.7_103); `jupiter-3.9`'s `steamos-26.05.21.1`
  reverts the whole batched sparse binding for the stable branch.
  The upstream side on 2026-11-11: nothing Io waits for has moved
  (gamescope's newest tag is 3.17.0, SDDM's 0.21.0, iwd's 3.12, hostap's
  2.12; PipeWire 1.6.11 and kwin 6.8.3 are released, Void has 1.6.10 and
  6.7.5; scx 1.1.4 is out, Void has 1.1.3). Comparisons are made
  against Valve's manifests and source archives: the Deck runs only Io
  since 2026-10-31, so there are no new SteamOS captures
- **Flavours:** *Plasma* (today's image), *Base* (game mode only), *Slim*
  (a light desktop). The split is prepared: `io-base` is the core,
  `io-desktop` adds the desktop
- **Automation:** done since 2026-10-31: the upstream check (GitHub
  Actions, every 8 hours: Valve's packages and release branches, the
  overlays against Void, the Void packages Io waits for, Valve's, Void's
  and kernel.org's kernels, Valve's steamos-manager against the template; findings
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
- SteamOS Manager: Io's seven runit commits (`git am` of the template's
  patches onto Valve's main) rebased onto Valve's update, every commit
  built (`cargo check --all-targets`), tests, fmt and clippy on the
  result, then `git format-patch` back into `patches/` and the template
  raised (`_commit`, checksum; version: 26.4.1 with the date of Valve's
  newest commit)
- After Void updates: `./build.sh -p --overlays` (rebuilds what Void
  rebuilt; stops for a review when Void moved to a new version), see
  [Building](Building)
- Valve's kernel updates, with the configuration review described on
  [Kernel](Kernel)
- Boot logs, for regressions and new warnings
