# Alpha 6 — in progress

**Status:** in progress, theme not chosen yet. What is planned and open is
on [Milestones](Milestones); this page collects what has changed since
[Alpha 5](Alpha-5) and becomes the release page.

## Changes so far

### Image build

- **New build pipeline in `build/`** replacing the old `mkimg.sh`:
  `mkrootfs.sh` installs Io once into a directory and packs it,
  `mkimg.sh` makes `io.img` from that tarball, `mkrecovery.sh` the recovery
  stick (see [Building](Building)). An image built this way matched one
  from the old script, apart from fstab by UUID and the 2.6 GB xbps cache,
  which is no longer left in the image.
- **`--clean`** only removes the script's own results; `BUILD_ROOTFS=1` or
  `=clean` runs `mkrootfs.sh` first.

### Recovery stick

- A small writable Void system with Plasma on a USB drive, with Io's
  system tarball inside ([Installation](Installation)): autologin, Install
  Io and Repair Io on the desktop, disk choice and confirmations in dialogs
  (touch or trackpad), Maliit as on-screen keyboard (opens on touch), sshd
  and socklog for inspecting a stick that does not come up.
- Boots with Io's kernel command line (without the splash options) and
  `amdgpu` in the initramfs; SDDM through a service of its own; its locale
  is generated.
- Installing with it is not released: it is tested with the move to the
  internal NVMe.

### Graphics

- **`gamescope-wsi-32bit`:** gamescope's WSI layer for 32-bit Vulkan games
  (SteamOS: `lib32-gamescope`). Confirmed on the Deck with Worms
  Armageddon (D3D9 through DXVK): the layer is loaded, Steam's frame limit
  works.

### System

- **Hibernation** only with `/` on the internal NVMe *and* `resume=` on the
  kernel command line (`steamos-tuning` 1.2_4).

### Packaging

- `build.sh` builds `archs="i686"` packages in an i686 masterdir,
  `publish.sh` publishes their `-32bit` package.
- `io-selftest.sh`: storage section, the 32-bit WSI layer.

### Decisions

- Valve's Mesa is not ported; VRAM priority for the foreground game is not
  implemented. Reasons on [Deviations](Deviations).
- The reference moves from SteamOS 3.8.4 to **SteamOS 3.9.2** (2026-10-04):
  a new capture with the Steam beta client and a guided test run with D-Bus
  per step showed Io's ported packages already at 3.9.2's versions, apart
  from the updates planned on [Milestones](Milestones).
- Input methods for Steam's keyboard (Chinese, Japanese, Korean) will be
  added for completeness.

### Closed by the 3.9.2 captures

- Notifications from a test in game mode and the developer *Speaker Test*
  show nothing on SteamOS either: Io behaves the same.
- *Use Legacy X11 Desktop Mode*: cause confirmed, stays a documented
  deviation.
