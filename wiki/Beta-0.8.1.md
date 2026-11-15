# Beta 0.8.1 — Kernel 7.3, Io's own patch notes, release automation

**Released:** [beta-0.8.1](https://github.com/Lolzen/io-packages/releases/tag/beta-0.8.1)

**Goal:** a catch-up release after three weeks of package updates: Valve's
first 7.3 kernels, Void's and Valve's newer packages, the fixes found
since Beta 0.8, and the first release built and published by Io's release
workflow. What is open afterwards is on [Milestones](Milestones).

## Highlights

- **Kernel 7.3:** Valve's `7.3.1-valve2` with stable 7.3.4 merged in
  (`linux-neptune-73`, metapackage `linux-neptune`); `7.2` stays installed
  as a fallback. The amdgpu explicit sync series is back, so Mesa's
  `radv_vm_explicit_sync` works again. See [Kernel](Kernel).
- **No more hang at the boot logo:** SDDM waits for elogind on the system
  bus.
- **Io's own patch notes in Steam:** the SteamOS update page shows Io's
  notes and the pending update's package changes, listed before later
  Steam client updates.
- **Boot splash:** the Io logo at boot, kept until game mode; the animated
  *Io Torus* during firmware updates.
- **Screen sharing without a prompt** and **text from Steam's keyboard in
  the desktop** (umlauts, emoji) through Io's portal and Xwayland overlays.
- **Release workflow:** this release was built, signed and published by
  GitHub Actions (*Create next release*); an upstream check reports new
  Valve, Void and kernel.org versions every 8 hours.

## Changes

### Kernel

- **`linux-neptune-73` 7.3.4:** Io's own port of Valve's 7.3 branch from
  2026-11-05 (7.3.1 to 7.3.4), replaced by Valve's `7.3.1-valve1` on
  2026-11-12 and `7.3.1-valve2` on 2026-11-14 (adds the HDMI 2.1 series
  for the Steam Machine), each with stable 7.3.4 merged in. Valve's
  configuration files are unchanged from 7.2.10.
- **`amdgpu.dcdebugmask=0x60000`** as on Valve's main: a linear brightness
  curve across the full range (`io-base` migrates existing installations).
- **Metapackage `linux-neptune`:** names Io's kernel series, so the next
  series comes as an ordinary update.

### Boot and session

- **SDDM waits for elogind** (`io-session` 0.7.7): with kernel 7.3 the
  greeter could start before elogind owned its bus name and the boot hung
  at the logo.
- **Boot splash** (`io-branding` 0.4.1, `plymouth-holo` with Valve's
  patches): the still logo at boot; the Torus animation and texts during
  firmware updates.
- **Shutdown and reboot from the power menu** no longer crash elogind's
  helper (`elogind-holo`, elogind's own fix).
- **Hibernation off on the Deck** (`jupiter-hibernate-disable`), as on
  SteamOS.

### Steam

- **Patch notes** (`io-changelog` 0.1.2): the SteamOS event of Steam's
  update page shows Io's notes (`steam.json`) and the summary of the
  pending update; it takes the date of Io's notes, and Steam's older
  SteamOS events leave the list.
- **SteamOS Manager** from Valve's source (main of 2026-11-10) with Io's
  seven runit commits as the package's patches, in place of a fork.
- **steamdeck-kde-presets 3.9.6:** "Add to Steam" in Dolphin passes the
  file name to Python as an argument (a name with a quote could run code).

### Desktop

- **Screen sharing:** `xdg-desktop-portal-kde-holo` with Valve's patch,
  Steam shares the screen without asking.
- **Steam's keyboard:** `xorg-server-xwayland-holo` 24.1.14 with Valve's
  libei patch: text and keysyms from other layout groups arrive.
- **Orca** with Valve's patches (`orca-holo`): keeps running when speech
  settings change.

### Wi-Fi, Bluetooth and audio

- **NetworkManager-holo:** Valve's ARP flux fix, no false IPv4 address
  conflict between Wi-Fi and the dock's Ethernet in the same network.
- **bluez-holo 5.88** (Void's) with Io's two patches.
- **steamdeck-dsp 1.04:** headphones stay awake through 15 minutes of
  silence (no clicks); Bluetooth audio independent of logind under
  WirePlumber 0.5.18.
- **vpower 1.6.4:** charge and discharge times from the battery voltage.

### Graphics

- **Mesa 26.2.7** (Void's) with Valve's 14 patches (`mesa-holo`).
- **gamescope-wsi 3.17.0** for 32-bit games.

### Valve's packages

- `deck-hw-support` 20260807.1_21 (SD card rescan through `io-detach`,
  udisks messages), `galileo-mura` v0.20 (OLED; drops root rights before
  writing), `steamdeck-dsp` 1.04, `vpower` 1.6.4.

### Tooling

- **Upstream check** (GitHub Actions, every 8 hours): Valve's source
  mirror (main, 3.9 and 3.10 branches), Io's overlays against Void, the
  Void packages Io waits for, Valve's, Void's and kernel.org's kernels,
  Valve's steamos-manager; findings in one issue.
- **Create next release** (GitHub Actions): version step, io-release,
  fresh rootfs and images, signing, release with notes. See
  [Building](Building).
- `publish.sh`: a `--testing` run keeps other branches' test packages;
  only x86_64 and noarch files.

## Decided

- **Io's own kernel port ends with Valve's 7.3 tag:** Io follows Valve's
  tags and merges newer stable releases into them.
- **Overlays follow Void's version;** Xwayland 24.1.15 (X.Org security
  advisory of 2026-11-10) is prepared separately while Void still has
  24.1.14.
- **Plasma 6.8** comes with Void, together with Valve's 6.8 patches
  (lock screen keyboard, kwin's handheld scale).

## Known limitations

- The Steam Deck OLED, the Steam Machine and Valve's dock are untested.
- A real BIOS or controller update is untested (only the checks and
  Valve's simulated update).
- Xwayland is 24.1.14, without the fixes of X.Org's advisory of
  2026-11-10.
- `€` (the AltGr level) from Steam's keyboard does not arrive in the
  desktop.
- Controller navigation in game mode is sometimes dead after a boot until
  the Steam button is pressed (Steam's,
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921)).
- During a firmware update on the Deck the Torus animation seemed hidden
  behind the logo (simulated update).
