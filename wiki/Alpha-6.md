# Alpha 6 — SteamOS 3.9.2 parity

**Status:** all planned work is done and tested on the Deck, except the
recovery stick with `plasma-keyboard` (not built since the switch); the
release itself (`io-release` 0.6) is still to come. Theme: *SteamOS 3.9.2 parity*.
What is open afterwards is on [Milestones](Milestones).

## Highlights

- **System updates from Steam.** Steam's update check under Settings →
  System finds Io's and Void's package updates and installs them with
  xbps, with Steam's progress display; a reboot completes the update.
- **SteamOS 3.9.2 as the reference** (until now 3.8.4), and Io's packages
  brought to its versions: kernel 7.2.7, `cecd` 0.3.0, `gpu-trace` 2.16,
  `steamos-networking-tools` 1.3, `holo-realtek-firmware-toggles` 1.3-3.
- **Steam's CEC switches work** (`HdmiCec2`), the desktop switch through
  Steam's menu (`SwitchToDesktopSession`), download mode sets the fan to
  2000 rpm as on SteamOS.
- **Chinese, Japanese and Korean input** on Steam's keyboard in game mode.
- **The Io overlay:** Void packages with Valve's patches, built as
  `-holo` packages that replace Void's (MangoHud, NetworkManager, bluez).
- **The desktop keeps game mode's brightness**; Plasma's on-screen keyboard
  is `plasma-keyboard`, as on SteamOS 3.9.2.

## Changes

### Fixes found by comparing with SteamOS 3.9.2

- **GPU clock:** Io stayed at a fixed 1600 MHz after every Steam start:
  setting the manual GPU clock switched the GPU to manual mode itself.
  Now, as in Valve's `steamos-manager`, the clock is only set in manual
  mode, and an error is reported otherwise.
- **Proton's nice limit** as on SteamOS 3.9.2 (`* hard nice -8` in
  `/etc/security/limits.d/15-proton-nice.conf`); `deck` is no longer in the
  `gamemode` group, which gave Steam a nice limit of 30.
- **Open-file limit** 1024 soft / 524288 hard (SteamOS gets it from
  systemd; Io had the kernel's 4096).
- **kwin's realtime threads:** `kwin_wayland` gets `CAP_SYS_NICE` as a file
  capability at boot, like gamescope (Arch's kwin package sets it).
- **sysctls:** ufw no longer applies its own `sysctl.conf` at boot
  (`jupiter-firewall` empties `IPT_SYSCTL`), which had overridden
  `rp_filter` and `accept_redirects`; `ping_group_range` and
  `net.unix.max_dgram_qlen` 512 as on SteamOS.
- **Game mode session as Valve's 3.9.2 script:** `STEAM_USE_WPASUPPLICANT=1`,
  `GAMESCOPE_DISPLAY_DISABLED=1`, without `GAMESCOPE_DISABLE_ASYNC_FLIPS`
  and `--cursor-scale-height`; `LIBVA_DRIVER_NAME=radeonsi` for every
  login; `ibus-daemon` for Steam's keyboard, started after gamescope.
- **Bluetooth** with SteamOS's settings (`MultiProfile`, `FastConnectable`,
  scan window during suspend), from a file of Io's own that the
  `bluetoothd` service is pointed at.
- `steamos-select-branch -c` answers `rel`, as on SteamOS; `Audio1` removed
  from SteamOS Manager, as Valve did.

### Updates to SteamOS 3.9.2's versions

- **Kernel 7.2.7** (`7.2.7-valve1`), now configured from the configuration
  Valve's package really builds from (`config.x86_64` + `config-neptune`)
  instead of the in-tree CI configuration: 9 options apart from Valve's
  build instead of 132. Transparent huge pages for
  shared memory are `advise`, as on SteamOS. See [Kernel](Kernel).
- **`deck-firmware`** (new): Valve's older `vangogh_vcn.bin` (AMD withdrew
  the version Void ships) and Valve's Realtek Bluetooth firmware, in
  `/usr/lib/firmware/updates`.
- **`cecd` 0.3.0:** puts the TV in standby on suspend, *Request Active
  Source*, no reply loop on *Feature Abort*.
- `gpu-trace` 2.16 (shuts down cleanly), `holo-realtek-firmware-toggles`
  1.3-3, `steamos-networking-tools` 1.3, `steamos-tuning` checked against
  `steamos-customizations-jupiter` 20260827.2 (`EDITOR=vim` as on SteamOS).

### SteamOS Manager (`io-steamos-manager` 0.14.0)

- **`HdmiCec2`**, which Steam's CEC switches in the power menu use, and
  `HdmiCec1` reworked onto `cecd`'s own D-Bus interface; `HdmiCecState` 3
  ("Extended").
- **`SwitchToDesktopSession`**.
- **Download mode** sets the fan to 2000 rpm, as `steamos-manager` does,
  and gives fan control back afterwards.
- **`com.steampowered.Atomupd1`** on the root half, with xbps behind it
  (see *System updates*).

### Input and desktop

- **Chinese, Japanese and Korean input** on Steam's keyboard: new packages
  `pyzy`, `ibus-pinyin` (layouts *pinyin*, *bopomofo*), `ibus-table` and
  Valve's `ibus-table-cangjie-lite` (*cangjie*, *quick*),
  `ibus-anthy-holo` (Valve's fork, Japanese), Void's `ibus-hangul`, and the
  Noto CJK fonts.
- **`plasma-keyboard`** instead of Maliit, in the desktop (switched on in
  System Settings, as on SteamOS) and on the recovery stick (set there; not
  built and tested yet). It types umlauts.
- **The desktop keeps the brightness set in game mode:** `io-plasma` writes
  it into kwin's saved output configuration before kwin starts (Valve
  patches kwin for this).
- In game mode, Steam's keyboard now types umlauts too (on SteamOS 3.9.2
  it does not; why it works on Io was not looked into).

### Io overlay

- New: **`overlay/`** in io-packages. Void packages that need a patch are
  built from Void's current template as `<name>-holo` packages that replace
  Void's; `build.sh` generates them and stops for a review when Void moves
  to a new version (see [Building](Building)).
- **`MangoHud-holo`:** mangoapp draws the performance overlay once per game
  frame again (mangoapp's CPU use 8.4 % → 2.4 % in a test).
- **`NetworkManager-holo`:** after resume, Wi-Fi scans only the frequency it
  was on (Valve's patch; 1.43 s → 1.30 s to reconnect at home; the gain
  should be larger where many networks are around, not measured).
- **`bluez-holo`:** Valve's fixes for re-paired devices (Steam Controller and
  suspend) and the Switch Pro Controller.
- `ibus-anthy-jupiter` is now `ibus-anthy-holo`.

### System updates

- Steam's update check and *Apply* run Io's `steamos-update`, which behaves
  like Valve's script (exit codes, progress lines, *Update completed*),
  with xbps behind it: `xbps` itself first when needed, then everything
  else; a reboot completes it (until then the check reports the update as
  applied). Log:
  `/var/log/io-update.log`. See [Helper status](Helper-Status).

### Image build and recovery stick

- **New build pipeline in `build/`** replacing the old `mkimg.sh`:
  `mkrootfs.sh` installs Io once into a directory and packs it,
  `mkimg.sh` makes `io.img` from that tarball, `mkrecovery.sh` the recovery
  stick (see [Building](Building)). The 2.6 GB xbps cache is no longer left
  in the image; `--clean` only removes the script's own results;
  `BUILD_ROOTFS=1` or `=clean` runs `mkrootfs.sh` first.
- **Recovery stick:** a small writable Void system with Plasma on a USB
  drive, with Io's system tarball inside ([Installation](Installation)):
  autologin, Install Io and Repair Io on the desktop, dialogs for touch or
  trackpad, on-screen keyboard on touch, sshd and socklog. Installing with
  it is not released: it is tested with the move to the internal NVMe.

### Graphics

- **`gamescope-wsi-32bit`:** gamescope's WSI layer for 32-bit Vulkan games
  (SteamOS: `lib32-gamescope`); Steam's frame limit works for them.

### System

- **Hibernation** only with `/` on the internal NVMe *and* `resume=` on the
  kernel command line.

### Packaging

- `build.sh` builds overlay packages, copies subpackage links, runs
  `xbps-src clean` before each build, and builds `archs="i686"` packages in
  an i686 masterdir; `publish.sh` publishes overlay packages and the
  `-32bit` packages.
- `io-selftest.sh`: a storage section, the 32-bit WSI layer, and checks for
  the fixes above, the input methods, mangoapp from the overlay, Atomupd1
  and `steamos-update`.

## Decisions

- Valve's Mesa is not ported; VRAM priority for the foreground game is not
  implemented. Reasons on [Deviations](Deviations).
- Void's hardening sysctls (`kptr_restrict`, `kexec_load_disabled`,
  `unprivileged_bpf_disabled`) stay; a deviation.
- The kernel keeps SteamOS's order of security modules; TOMOYO's
  activation follows Void's `/sbin/init` with the next kernel update.
- The black screen between the desktop and game mode is not pursued;
  Twemoji (SteamOS's emoji look) is left for some day.
- The NetworkManager overlay is kept although the gain at home is small.

## Closed by the 3.9.2 captures

- Notifications from a test in game mode and the developer *Speaker Test*
  show nothing on SteamOS either: Io behaves the same.
- *Use Legacy X11 Desktop Mode*: cause confirmed, stays a documented
  deviation.
- Steam's keyboard loses umlauts and ß on SteamOS 3.9.2 too (system
  language English, German keyboard).
- HDMI-CEC with the JSAUX dock: no `/dev/cec*` on SteamOS either; the dock
  does not pass CEC through.

## Known limitations

- Pausing or cancelling a system update is refused (xbps cannot be stopped
  safely in the middle of a transaction).
- The TV side of HDMI-CEC is untested (needs a dock that passes CEC).
