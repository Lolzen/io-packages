# Installation

Io runs from an SD card, written from the release image, or from the
Deck's internal SSD, installed with the recovery stick. Installing with the
stick and *Repair Io* are tested on the internal NVMe; the stick itself is
not a release download yet and is built from io-packages (see
[Building](Building)).

---

## SD card

Io needs an SD card of **at least 32 GB** (the image is 16 GiB). Download all
`io.img.xz.part*` files and `io.img.xz.sha256` from the
[latest release](https://github.com/Lolzen/io-packages/releases/latest),
join and check them, then write the image to the card (replace `sdX` with
the card; everything on it is lost):

```
cat io.img.xz.part* > io.img.xz
sha256sum -c io.img.xz.sha256
xz -d io.img.xz
sudo dd if=io.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot the Deck from the card: hold **Volume Down**, press **Power**, pick the
card in the boot manager. *Restart* from Io starts Io again; switching the
Deck off and on starts the firmware's default system (SteamOS on the
internal SSD, if there is one).

**The first boot**

- goes straight into Steam: the client comes preinstalled, as on SteamOS
- Steam's own first-run setup connects to Wi-Fi with the Deck's controls; no
  keyboard or Ethernet needed
- takes a little longer than later boots while Steam unpacks itself

**Then** run *Expand storage* from the desktop menu (or `io-grow-storage` in
a terminal) to use the whole card. It shows what it will do and asks first.

User and password: `deck` / `deck`. **The SSH server is on during the test
phase**; change the password with `passwd` before using Io on a network you
do not trust.

---

## Recovery stick

A small writable Void system with Plasma on a USB drive, with Io's system
tarball inside. It only has to boot to a desktop from which the install
scripts run. How to build it is on [Building](Building).

```
sudo dd if=recovery.img of=/dev/sdX bs=4M status=progress conv=fsync
```

- **Boot:** hold Volume Down, press Power, pick the USB drive.
- **Login:** automatic, user `iorecovery`. Its password and root's are
  `deck` on purpose: a recovery system that locks its user out defeats its
  purpose. `iorecovery` has sudo without a password.
- **On the desktop:**
  - *Install Io* — pick the target disk in a list, confirm twice; the disk
    is **erased** and Io installed on it (`io-install` → `io-restore`). The
    disk the stick runs from, and disks with a mounted partition or active
    swap, are refused.
  - *Repair Io* — pick an Io installation (internal NVMe, SD card or USB
    drive; found by its `IOROOT` partition) and the repairs: check and
    repair the filesystems, rebuild the initramfs, reinstall the boot
    loader, forget a hibernated session that does not resume (the session
    is lost), check the installed packages, request a factory reset (Io
    erases all user data at its next start), open a root shell in the
    installation (`io-repair`). Tested on the internal NVMe (2026-10-20).
- **Everything works by touch or with the trackpad.** The dialogs need no
  keyboard.
- **The on-screen keyboard opens only on touch.** To type into the
  terminal, tap into its window with a finger once. A click with the
  trackpad or R2 does not open it (KWin shows its virtual keyboard only for
  touch input).
- **SSH:** log in as `iorecovery`. Root cannot log in with a password over
  SSH (OpenSSH's default `PermitRootLogin prohibit-password`); use `sudo`.

**Status:** the stick boots, starts Plasma, and the disk dialog works.
Installing to the internal NVMe and *Repair Io* are tested (2026-10-19
and 20): take out SD cards you do not want listed as a target first, the
dialog offers every disk but the stick's.
