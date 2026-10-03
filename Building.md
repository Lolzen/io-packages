# Building

## Layout

```
~/void-packages     xbps-src checkout, builds happen here
~/io-packages       this repository: templates, scripts
~/io-repo-pub       local copy of the published repository (created by publish.sh)
```

Requirements: a working `xbps-src` setup, `gh` authenticated for the
`io-repo` repository, and the repository signing key at
`~/io-packages/privkey.pem`.

## Building and publishing packages

```
~/io-packages/build.sh io-session io-base       build
~/io-packages/build.sh -p io-session io-base    build and publish
```

`build.sh` first pulls `void-packages` (a stale checkout makes `xbps-src`
build dependencies from source instead of taking Void's binaries), then
copies the named packages from `io-packages` into `void-packages` and runs
`xbps-src pkg` for each. It copies rather than symlinks: `xbps-src`
builds inside a chroot that only sees the `void-packages` tree, where a link
into `io-packages` would point nowhere. Naming a subpackage
(`linux-neptune-72-headers`) copies its main package too.

**Bump `revision` in the template for every change**, or the build produces
the same file name and `publish.sh` treats it as already published.

**Versions of Io's own packages:** a change of content (a new feature, a
changed behaviour) raises the version and resets the revision to 1;
packaging-only changes raise the revision. Ported packages keep their
upstream version. 1.0 is reserved for the beta.

**32-bit packages:** a template with `archs="i686"` (today
`gamescope-wsi`) is built by `build.sh` in an i686 masterdir
(`xbps-src -A i686`, created on first use). xbps-src's 32-bit hook turns the
result into `<name>-32bit` in `binpkgs/multilib`, and `publish.sh` publishes
that package, never the i686 one. The template sets `lib32mode=full` and
names the libraries to link with `lib32symlinks`.

Large sources can be put into `xbps-src`'s cache beforehand to avoid a second
download, e.g. `steam-jupiter`'s 428 MB archive into
`~/void-packages/hostdir/sources/steam-jupiter-<version>/`.

`publish.sh` (also callable on its own, with package names or without):

1. copies the newest build of each package listed in `srcpkgs/` out of
   `void-packages/hostdir/binpkgs` — unrelated packages that `xbps-src`
   rebuilt along the way stay out
2. keeps exactly one version per package, and drops packages that no longer
   exist in `srcpkgs/`
3. indexes and signs what is new
4. uploads only files the release does not have yet, then the index
5. deletes release assets that are no longer part of the repository

`publish.sh --full` re-indexes and re-uploads everything.

## Updating a device

```
sudo xbps-install -Syu
```

Without package names: naming packages updates only those, not their
dependencies.

Changes to the session scripts and to audio configuration take effect with
the next session (a switch to the desktop and back); a cold boot is the
reliable test.

## Testing a build before publishing

A build that needs the Deck before it goes public is copied there and
installed from a local repository. On the build host, without `-p`:

```
~/io-packages/build.sh io-session io-desktop
cd ~/void-packages/hostdir/binpkgs
scp io-session-<version>_<revision>.* io-desktop-<version>_<revision>.* deck@<deck>:/tmp/trepo/
```

On the Deck (create `/tmp/trepo` first, and empty it between tests):

```
xbps-rindex -a /tmp/trepo/*.xbps
sudo xbps-install -R /tmp/trepo -Su io-session io-desktop
```

Naming the packages is right here, unlike a normal update: only the tested
ones should come from the local repository. Once the test passes,
`build.sh -p` with the same package names publishes them.

## Kernel updates

See [Kernel](Kernel): the configuration is reviewed on every update before
the kernel is built.

## Building images

The scripts are in `build/` (details in its `README.md`; settings in
`build/config/`, package lists in `build/packages/`). Two steps:

```
build/mkrootfs.sh ──► io-rootfs.tar.zst ──┬──► build/mkimg.sh ──────► io.img
                                          └──► build/mkrecovery.sh ─► recovery.img
```

```
sudo build/mkrootfs.sh --clean
sudo build/mkimg.sh
sudo build/mkrecovery.sh
```

- **`mkrootfs.sh`** installs `io-desktop` from the published repository
  into a directory (`/home/gee/io-build/io-rootfs`), sets up locales, users,
  services and GRUB's defaults with Io's kernel command line, and packs it
  with every xattr and ACL (file capabilities included). What depends on
  the disk is left out of the tarball. The xbps cache and the root's shell
  history are removed before packing.
- **`mkimg.sh`** writes the tarball into `/home/gee/io.img` (16 GiB) and
  adds what depends on the disk: fstab by UUID, the initramfs, GRUB in
  removable mode.
- **`mkrecovery.sh`** builds the recovery stick (see
  [Installation](Installation)): a Void system with Plasma, the tarball
  inside, its size worked out from the contents.
- **`--clean`** removes the script's own earlier results, nothing else:
  `mkrootfs.sh` the rootfs and tarball, `mkimg.sh` the image,
  `mkrecovery.sh` the recovery rootfs and image. Without it the scripts ask
  before reusing one; a kept root is updated before the package list is
  installed.
- **`BUILD_ROOTFS=1`** makes `mkimg.sh` or `mkrecovery.sh` run `mkrootfs.sh`
  first; `BUILD_ROOTFS=clean` runs it with `--clean`.
- **`TRIM=1`** shrinks an image to its contents plus a margin (2 GiB for
  `io.img`, the free space until the user expands the storage).
- Other settings through the environment, as in `build/config/system.conf`:
  `SIZE`, `OUT`, `USERNAME`, `USERPASS`, `ROOTPASS`, `HOSTNAME`,
  `TIMEZONE` (default `UTC`; Steam sets the user's zone).

`deck` is the default user, as on SteamOS. With another `USERNAME`, three
places still name `deck` and have to be changed by hand: SDDM's autologin
(`User=` in `/usr/lib/sddm/sddm.conf.d/10-io.conf`), the devkit service
(`/etc/sv/steamos-devkit-service/run`) and Valve's automount script
(`/usr/lib/hwsupport/steamos-automount.sh`, which stops without a user
`deck`). A package update puts all three back.

Write an image to a card (replace `sdX`; check with `lsblk` first):

```
sudo dd if=/home/gee/io.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Checking a system

```
sudo sh io-selftest.sh
```

Run on the device in game mode. Checks kernel, packages, services, memory
setup, the game mode session, SteamOS Manager, audio configuration, logging
and the package database against the expected state; every line is PASS,
FAIL or INFO. Like `io-boottime.sh` it is a developer script, not packaged;
it is brought up to date for each release.

```
sudo sh io-boottime.sh
```

Right after a cold boot, before switching sessions: the second after kernel
start at which each boot stage began.

## Other tools

| Script | Use |
|---|---|
| `io-boottime.sh` | Boot stage timing, see above |
| `mountsd.sh /dev/sdX` | Mount an Io card on the build host and prepare a chroot for repairs |
| `pkgcheck.sh` | Report new or changed packages on Valve's source mirror |
| `mklogo.py` | Generates the ASCII logo (source of `io-branding`'s `io.txt`) |

## Release workflow

1. The milestone's items done, or left open on [Milestones](Milestones)
2. Fresh image built (`build/`), written to a spare card, booted, storage grown,
   `io-selftest.sh` passes
3. The release page written (see [Changelog](Changelog)): goal,
   highlights, changes by area, known limitations; done items removed from
   [Milestones](Milestones)
4. Remove the previous release's `io.img.xz*` files first — a leftover part
   would be joined into the new image. Then compress the image and split it
   below GitHub's 2 GiB asset limit:
   ```
   xz -T0 -k io.img
   split -b 1900M -d io.img.xz io.img.xz.part
   sha256sum io.img.xz > io.img.xz.sha256
   ```
   Check that `cat io.img.xz.part* | sha256sum` matches the checksum.
5. Tag, create the release, attach the parts and the checksum

Users rebuild the image with `cat io.img.xz.part* > io.img.xz`.
