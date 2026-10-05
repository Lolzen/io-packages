#!/bin/sh
# build.sh - update void-packages, copy Io packages into it and build them.
#
# Usage:
#   ./build.sh io-session io-base      copy and build these packages
#   ./build.sh -p io-session io-base   same, then publish them
#   ./publish.sh io-session io-base    publish only (already built), e.g.
#                                      after a run that stopped half-way
#   ./build.sh -p MangoHud-holo        an overlay package (overlay/MangoHud):
#                                      generated from Void's MangoHud first
#   ./build.sh -p --overlays           every overlay whose current build is
#                                      missing (after a Void update, say)
#
# Overlays (overlay/README.md): <name>-holo is generated from Void's <name>
# by overlay/holo.sh after void-packages is pulled. If Void's version is not
# the one the overlay's patches are made for, that overlay is not built and
# the run ends with exit status 2: check the patches, then raise
# base_version in overlay/<name>/overlay.conf.
#
# xbps-src builds inside a chroot that only sees the void-packages tree, so
# the templates are copied, not symlinked: a symlink pointing into
# io-packages would dangle inside the chroot. The old copy is removed first,
# so files deleted in io-packages do not linger in void-packages.
#
# Subpackages (linux-neptune-72-headers, ...) are symlinks to their main
# package in srcpkgs/; naming one copies the main package as well, and
# copying a main package copies its subpackage links.
#
# A package with archs="i686" (gamescope-wsi) is built in an i686 masterdir
# (xbps-src -A i686, created on first use); xbps-src turns it into
# <name>-32bit for the x86_64 multilib repository, which publish.sh takes.

set -eu

IO_DIR="${IO_DIR:-$HOME/io-packages}"
VP_DIR="${VP_DIR:-$HOME/void-packages}"

PUBLISH=0
if [ "${1:-}" = "-p" ]; then
    PUBLISH=1
    shift
fi

if [ $# -eq 0 ]; then
    echo "usage: build.sh [-p] <pkgname|name-holo|--overlays> [more...]" >&2
    exit 1
fi

# Bring void-packages up to date first. Build dependencies come as binary
# packages from Void's repository only while the local templates match its
# versions; with a stale checkout xbps-src builds them from source instead,
# which takes long (and would not match what the Deck installs).
if ! git -C "$VP_DIR" pull --ff-only --quiet; then
    echo "build: 'git pull' in $VP_DIR failed - resolve that first" >&2
    exit 1
fi

HOLO="$IO_DIR/overlay/holo.sh"
export IO_DIR VP_DIR

copy_pkg() {
    rm -rf "$VP_DIR/srcpkgs/$1"
    cp -a "$IO_DIR/srcpkgs/$1" "$VP_DIR/srcpkgs/$1"
    echo "copied: $1"
    # xbps-src needs the subpackage links next to the main package
    # (srcpkgs/<subpkg> -> <main>), or it stops with "nonexistent file".
    for link in "$IO_DIR"/srcpkgs/*; do
        [ -L "$link" ] || continue
        [ "$(readlink "$link")" = "$1" ] || continue
        rm -rf "$VP_DIR/srcpkgs/${link##*/}"
        cp -a "$link" "$VP_DIR/srcpkgs/${link##*/}"
        echo "copied: ${link##*/} -> $1"
    done
}

is_overlay() {
    case "$1" in
        *-holo) [ -f "$IO_DIR/overlay/${1%-holo}/overlay.conf" ] ;;
        *) return 1 ;;
    esac
}

# --overlays: the overlays whose current build is missing
REVIEW=0
PKGS=""
for pkg in "$@"; do
    if [ "$pkg" = "--overlays" ]; then
        sh "$HOLO" check || REVIEW=1
        PKGS="$PKGS $(sh "$HOLO" tobuild)"
    else
        PKGS="$PKGS $pkg"
    fi
done

BUILD=""
for pkg in $PKGS; do
    if is_overlay "$pkg"; then
        rc=0
        sh "$HOLO" gen "${pkg%-holo}" || rc=$?
        case $rc in
            0) BUILD="$BUILD $pkg" ;;
            2) REVIEW=1 ;;
            *) exit "$rc" ;;
        esac
        continue
    fi
    src="$IO_DIR/srcpkgs/$pkg"
    if [ ! -e "$src" ]; then
        echo "build: no package '$pkg' in $IO_DIR/srcpkgs or overlay/" >&2
        exit 1
    fi
    if [ -L "$src" ]; then
        copy_pkg "$(readlink "$src")"
    fi
    copy_pkg "$pkg"
    BUILD="$BUILD $pkg"
done

# "xbps-src clean" first: after a failed build xbps-src resumes in the old
# build directory and skips extract and patch, so changed patches (or a
# regenerated overlay) would not be applied.
cd "$VP_DIR"
for pkg in $BUILD; do
    if grep -q '^archs="i686"' "srcpkgs/$pkg/template"; then
        ./xbps-src -A i686 clean "$pkg"
        ./xbps-src -A i686 pkg "$pkg"
    else
        ./xbps-src clean "$pkg"
        ./xbps-src pkg "$pkg"
    fi
done

# An overlay publishes all its packages (MangoHud-holo and
# MangoHud-mangoapp-holo, ...).
if [ "$PUBLISH" = 1 ] && [ -n "$BUILD" ]; then
    PUB=""
    for pkg in $BUILD; do
        if is_overlay "$pkg"; then
            PUB="$PUB $(sh "$HOLO" names "${pkg%-holo}")"
        else
            PUB="$PUB $pkg"
        fi
    done
    # shellcheck disable=SC2086
    "$IO_DIR/publish.sh" $PUB
fi

if [ "$REVIEW" = 1 ]; then
    echo "build: overlays need a review (see above); they were not built" >&2
    exit 2
fi
