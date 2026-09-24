#!/bin/sh
# build.sh - update void-packages, copy Io packages into it and build them.
#
# Usage:
#   ./build.sh io-session io-base      copy and build these packages
#   ./build.sh -p io-session io-base   same, then publish them
#
# xbps-src builds inside a chroot that only sees the void-packages tree, so
# the templates are copied, not symlinked: a symlink pointing into
# io-packages would dangle inside the chroot. The old copy is removed first,
# so files deleted in io-packages do not linger in void-packages.
#
# Subpackages (linux-neptune-72-headers, ...) are symlinks to their main
# package in srcpkgs/; naming one copies the main package as well.

set -eu

IO_DIR="${IO_DIR:-$HOME/io-packages}"
VP_DIR="${VP_DIR:-$HOME/void-packages}"

PUBLISH=0
if [ "${1:-}" = "-p" ]; then
    PUBLISH=1
    shift
fi

if [ $# -eq 0 ]; then
    echo "usage: build.sh [-p] <pkgname> [more...]" >&2
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

copy_pkg() {
    rm -rf "$VP_DIR/srcpkgs/$1"
    cp -a "$IO_DIR/srcpkgs/$1" "$VP_DIR/srcpkgs/$1"
    echo "copied: $1"
}

for pkg in "$@"; do
    src="$IO_DIR/srcpkgs/$pkg"
    if [ ! -e "$src" ]; then
        echo "build: no package '$pkg' in $IO_DIR/srcpkgs" >&2
        exit 1
    fi
    if [ -L "$src" ]; then
        copy_pkg "$(readlink "$src")"
    fi
    copy_pkg "$pkg"
done

cd "$VP_DIR"
for pkg in "$@"; do
    ./xbps-src pkg "$pkg"
done

if [ "$PUBLISH" = 1 ]; then
    "$IO_DIR/publish.sh" "$@"
fi
