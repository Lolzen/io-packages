# Io build scripts (rootfs, image, recovery)

How Io's images are built (this replaced the single `mkimg.sh` in the
repository's top directory after an image built both ways came out the
same, apart from fstab by UUID and the xbps cache left out). The build has
two steps:

```
mkrootfs.sh ──► io-rootfs.tar.zst ──┬──► mkimg.sh ──────► io.img
                                    └──► mkrecovery.sh ─► recovery.img
                                                           ├─ recovery system (Void, Plasma)
                                                           └─ io-rootfs.tar.zst (payload)
```

- **`mkrootfs.sh`** installs Io once into a directory (`io-desktop`, locales,
  users, services, GRUB's defaults with Io's kernel command line) and packs
  it. What depends on the disk Io lands on is left out of the tarball.
- **`mkimg.sh`** writes the tarball into `io.img` and adds what depends on
  the disk: fstab by UUID, the initramfs, GRUB in removable mode.
- **`mkrecovery.sh`** builds a small writable Void system with Plasma for a
  USB drive, with the tarball inside. Its desktop has *Install Io*
  (`io-install` → `io-restore`, erases the chosen disk) and *Repair Io* (a
  placeholder).

Settings are in `config/`, package lists in `packages/`, the recovery
system's tools in `recovery/`. Everything can be overridden from the
environment; the files say how.

## Usage

```
sudo ./mkrootfs.sh --clean
sudo ./mkimg.sh
sudo ./mkrecovery.sh
```

- `--clean` removes the earlier result first. Without it the scripts ask
  before reusing one; a kept root is updated (`xbps-install -Su`) before the
  package list is installed, so no old package slips into the tarball.
- `BUILD_ROOTFS=1` makes `mkimg.sh` or `mkrecovery.sh` run `mkrootfs.sh`
  first.
- `TRIM=1` shrinks an image to its contents plus `TRIM_MARGIN_MB` (2 GB for
  `io.img`: until the user expands the storage, that is all the free space
  there is).

## The recovery system

It only has to boot to a desktop from which the install scripts run. User
`iorecovery` logs in automatically, has sudo without a password, and both
it and root have the password `deck`: a recovery system that locks its
user out defeats its purpose.

`io-restore` refuses the disk the recovery system runs from and any disk
with a mounted partition or active swap. The installed system gets fstab by
UUID, a machine-id of its own, a fresh initramfs, an NVRAM boot entry
`Io`, and GRUB at the removable path as a fallback. Its partitions are
labelled `IOESP` and `IOROOT` like an Io card; the recovery drive's are
`IORECESP` and `IOREC`.

## Status

- `mkrootfs.sh` and `mkimg.sh`: in use. `compare-images.sh` compares two
  images file by file (packages, capabilities, configuration, ESP) when the
  pipeline changes.
- Recovery image: build and boot it; **do not install** with it yet.
  Installing to the internal SSD is a later milestone (it wipes SteamOS,
  the reference until then).
