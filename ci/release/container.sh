#!/bin/bash
# container.sh - the release workflow's steps that need Void: run as root in
# ghcr.io/void-linux/void-glibc-full (--privileged, /dev from the host for
# the loop devices), with io-packages at /src and the work directory at /work.
# The workflow starts the container once and runs each step with docker exec.
#
#   container.sh setup     xbps tools, a build user
#   container.sh pkg       build io-release from /src (template already
#                          raised) with xbps-src; result in /work/localrepo
#   container.sh images    io-rootfs.tar.zst, io.img and recovery.img from the
#                          published repository plus /work/localrepo; each
#                          image xz-compressed, split below GitHub's 2 GiB
#                          asset limit, with a checksum, in /work/out
#   container.sh sign      add io-release to a copy of current's index and
#                          sign both (key: /work/privkey.pem); in /work/pub
set -euo pipefail

SRC=/src
WORK=/work
log() { printf '\n==== %s\n' "$*"; }

setup() {
    mkdir -p /etc/xbps.d
    cp /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/
    xbps-install -Syu xbps
    xbps-install -yu
    xbps-install -y bash sudo git curl openssl zstd xz tar gptfdisk dosfstools e2fsprogs util-linux coreutils findutils
    id builder > /dev/null 2>&1 || useradd -G xbuilder -M builder
}

pkg() {
    local vp=$WORK/void-packages
    log "void-packages"
    rm -rf "$vp"
    git clone -q --depth 1 https://github.com/void-linux/void-packages "$vp"
    {
        echo XBPS_ALLOW_RESTRICTED=yes
        echo XBPS_CHROOT_CMD=uchroot
    } >> "$vp/etc/conf"
    chown -R builder:builder "$vp"
    log "binary-bootstrap"
    (cd "$vp" && sudo -u builder ./xbps-src binary-bootstrap)
    log "io-release"
    # build.sh copies the template from IO_DIR into void-packages and builds
    # it, exactly as on the build host (without -p: publishing is not done
    # here). It needs a copy it may read as the build user.
    rm -rf "$WORK/io-packages"
    cp -a "$SRC" "$WORK/io-packages"
    chown -R builder:builder "$WORK/io-packages"
    sudo -u builder env HOME="$WORK" IO_DIR="$WORK/io-packages" VP_DIR="$vp" sh "$WORK/io-packages/build.sh" io-release
    local f
    f=$(ls "$vp"/hostdir/binpkgs/io-release-*.xbps)
    rm -rf "$WORK/localrepo"
    mkdir -p "$WORK/localrepo"
    cp "$f" "$WORK/localrepo/"
    xbps-rindex -a "$WORK/localrepo/"*.xbps
    ls -l "$WORK/localrepo"
}

pack() {
    # $1 image -> $1.xz.partNN + $1.xz.sha256 in /work/out, the image removed
    local img=$1 base
    base=$(basename "$img")
    log "compressing $base"
    xz -T0 "$img"
    (cd "$(dirname "$img")" && sha256sum "$base.xz" > "$WORK/out/$base.xz.sha256")
    split -b 1900M -d "$img.xz" "$WORK/out/$base.xz.part"
    rm -f "$img.xz"
    # the parts joined must give the checksummed file
    local sum
    sum=$(cat "$WORK/out/$base.xz.part"* | sha256sum | cut -d' ' -f1)
    grep -q "^$sum " "$WORK/out/$base.xz.sha256" || { echo "parts of $base.xz do not match its checksum" >&2; exit 1; }
}

images() {
    local b=$WORK/build
    local want
    want=$(cd "$WORK/localrepo" && ls io-release-*.xbps | sed -E 's/\.(x86_64|noarch)\.xbps$//')
    mkdir -p "$b" "$WORK/out"
    rm -f "$WORK/out/"*
    export EXTRA_REPO=$WORK/localrepo WORKDIR=$b OUT=$b/io.img REC_OUT=$b/recovery.img
    export SYS_ROOTFS=$b/io-rootfs ROOTFS_TARBALL=$b/io-rootfs.tar.zst REC_ROOTFS=$b/recovery-rootfs
    log "mkrootfs"
    "$SRC/build/mkrootfs.sh" --clean
    local have
    have=$(xbps-query -r "$SYS_ROOTFS" -p pkgver io-release)
    echo "io-release in the rootfs: $have"
    [ "$have" = "$want" ] || { echo "expected $want" >&2; exit 1; }
    xbps-query -r "$SYS_ROOTFS" -l | awk '{print $2}' > "$WORK/out/packages.txt"
    rm -rf --one-file-system "$SYS_ROOTFS"
    df -h "$WORK"
    log "mkimg"
    "$SRC/build/mkimg.sh" --clean
    pack "$b/io.img"
    df -h "$WORK"
    log "mkrecovery"
    "$SRC/build/mkrecovery.sh" --clean
    rm -rf --one-file-system "$REC_ROOTFS"
    pack "$b/recovery.img"
    rm -f "$ROOTFS_TARBALL"
    ls -l "$WORK/out"
}

sign() {
    local pub=$WORK/pub f
    rm -rf "$pub"
    mkdir -p "$pub"
    curl -fsSL -o "$pub/x86_64-repodata" https://github.com/Lolzen/io-repo/releases/download/current/x86_64-repodata
    cp "$WORK/localrepo/"io-release-*.xbps "$pub/"
    f=$(ls "$pub"/io-release-*.xbps)
    # adds the entry and drops the older io-release from the index; the other
    # packages' entries stay as they are (their files are not needed here)
    xbps-rindex -a "$f"
    xbps-rindex --sign --signedby Io --privkey "$WORK/privkey.pem" "$pub"
    xbps-rindex --sign-pkg --privkey "$WORK/privkey.pem" "$f"
    ls -l "$pub"
}

case "${1:-}" in
    setup) setup ;;
    pkg) pkg ;;
    images) images ;;
    sign) sign ;;
    *) echo "usage: container.sh setup|pkg|images|sign" >&2; exit 1 ;;
esac
