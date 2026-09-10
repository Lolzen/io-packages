#!/bin/sh
# publish.sh - copy Io's own packages out of the xbps-src output directory,
# index and sign them, and push the result to the GitHub release that serves
# as Io's package repository.
#
# xbps-src's binpkgs also holds unrelated packages it happened to rebuild
# (openssl, pipewire, ...). Those must not end up in the repository, so this
# script copies by an explicit name list rather than wholesale.
#
# Usage:
#   ./publish.sh            publish everything
#   ./publish.sh io-base    publish one package (still reuploads the index)
#
# Requires: gh authenticated (or GH_TOKEN set), privkey.pem readable.

set -eu

BINPKGS="${BINPKGS:-$HOME/void-packages/hostdir/binpkgs}"
PUBDIR="${PUBDIR:-$HOME/io-repo-pub}"
PRIVKEY="${PRIVKEY:-$HOME/io-packages/privkey.pem}"
SIGNEDBY="${SIGNEDBY:-Io}"
GHREPO="${GHREPO:-Lolzen/io-repo}"
GHTAG="${GHTAG:-current}"

# Packages that belong in the repository. Anything else in binpkgs is a
# build dependency and stays out.
PACKAGES="
io-base
io-branding
io-desktop
io-session
io-steamos-manager
io-volumed
deck-firmware-cirrus
deck-hw-support
jupiter-fan-control
linux-neptune
linux-neptune-headers
steamos-powerbuttond
xdg-desktop-portal-gamescope
inputplumber
"

[ -f "$PRIVKEY" ] || { echo "publish: no private key at $PRIVKEY" >&2; exit 1; }
[ -d "$BINPKGS" ] || { echo "publish: no binpkgs at $BINPKGS" >&2; exit 1; }

mkdir -p "$PUBDIR"

# One package requested, or all of them.
if [ $# -gt 0 ]; then
    PACKAGES="$*"
fi

echo "== collecting"

for pkg in $PACKAGES; do
    # Newest revision only: sort -V puts e.g. _10 after _9.
    newest=$(ls "$BINPKGS/$pkg"-[0-9]*.x86_64.xbps 2>/dev/null \
             | grep -E "/${pkg}-[0-9][^/]*\.x86_64\.xbps$" \
             | sort -V | tail -1)

    if [ -z "$newest" ]; then
        echo "  $pkg: not built, skipping"
        continue
    fi

    base=$(basename "$newest")

    if [ -f "$PUBDIR/$base" ]; then
        echo "  $base: already present"
    else
        cp "$newest" "$PUBDIR/"
        echo "  $base: copied"
    fi

    # Drop older revisions of the same package from the publish dir, so the
    # release does not accumulate 170 MB of stale kernels.
    for old in "$PUBDIR/$pkg"-[0-9]*.x86_64.xbps; do
        [ -f "$old" ] || continue
        case "$(basename "$old")" in
            "$base") continue ;;
        esac
        case "$(basename "$old")" in
            "$pkg"-[0-9]*)
                # Guard against prefix collisions: linux-neptune must not
                # sweep away linux-neptune-headers.
                rest=${old#"$PUBDIR/$pkg"-}
                case "$rest" in
                    [0-9]*) ;;
                    *) continue ;;
                esac
                rm -f "$old" "$old.sig2"
                echo "  $(basename "$old"): removed (superseded)"
                ;;
        esac
    done
done

echo "== indexing"
xbps-rindex -a "$PUBDIR"/*.xbps
xbps-rindex -c "$PUBDIR"

echo "== signing"
xbps-rindex --sign --signedby "$SIGNEDBY" --privkey "$PRIVKEY" "$PUBDIR" 2>/dev/null || true
xbps-rindex --sign-pkg --privkey "$PRIVKEY" "$PUBDIR"/*.xbps

echo "== uploading"
gh release upload "$GHTAG" \
    "$PUBDIR"/*.xbps \
    "$PUBDIR"/*.sig2 \
    "$PUBDIR"/x86_64-repodata \
    --repo "$GHREPO" --clobber

echo
echo "published to https://github.com/$GHREPO/releases/tag/$GHTAG"
xbps-query --repository="$PUBDIR" -s io- || true