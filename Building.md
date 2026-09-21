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

`build.sh` copies the named packages from `io-packages` into `void-packages`
and runs `xbps-src pkg` for each. It copies rather than symlinks: `xbps-src`
builds inside a chroot that only sees the `void-packages` tree, where a link
into `io-packages` would point nowhere. Naming a subpackage
(`linux-neptune-72-headers`) copies its main package too.

**Bump `revision` in the template for every change**, or the build produces
the same file name and `publish.sh` treats it as already published.

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
sudo xbps-install -Syu <packages>
```

A cold boot afterwards is the reliable test: PipeWire keeps running across
session switches, so audio configuration changes need one anyway.

## Building an image

```
sudo ~/io-packages/mkimg.sh
```

Builds `/home/gee/io.img` (12 GB) from the published repository: partitions,
installs `io-desktop`, creates the user, enables services, installs GRUB and
the initramfs. Options through the environment: `SIZE=16G`, `OUT=...`,
`USERNAME`, `USERPASS`, `ROOTPASS`, `HOSTNAME`, `TIMEZONE`.

Write it to a card (replace `sdX`; check with `lsblk` first):

```
sudo dd if=/home/gee/io.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Checking a system

```
sudo sh io-selftest.sh
```

Run on the device in game mode. Checks kernel, packages, services, memory
setup, the game mode session, SteamOS Manager, audio configuration, logging
and the package database against the expected state; every line is PASS or
FAIL.

## Other tools

| Script | Use |
|---|---|
| `mountsd.sh /dev/sdX` | Mount an Io card on the build host and prepare a chroot for repairs |
| `pkgcheck.sh` | Report new or changed packages on Valve's source mirror |
| `mkiso.sh` | Live ISO build through void-mklive — currently blocked, kept for a later attempt |
| `mklogo.py` | Generates the ASCII logo |

## Release workflow

1. All open items of the milestone done or moved (see [Milestones](Milestones))
2. Fresh image built, written to a spare card, booted, storage grown,
   `io-selftest.sh` passes
3. Final state written on the milestone page
4. Tag and release
