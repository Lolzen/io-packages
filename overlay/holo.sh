#!/bin/sh
# holo.sh - Io's overlay: Void packages with Io's (mostly Valve's) patches,
# built as packages of their own (<name>-holo) that replace Void's.
#
# Usage:
#   overlay/holo.sh check        status of every overlay (no changes)
#   overlay/holo.sh gen <name>   write srcpkgs/<name>-holo into void-packages
#   overlay/holo.sh names [name] package names the overlays produce
#   overlay/holo.sh tobuild      overlays whose current build is missing
#   overlay/holo.sh lib32 <name> exit 0 if the overlay is built for i686 too
#
# An overlay is overlay/<name>/ with:
#   overlay.conf   base_version=<Void version the patches are made for>
#                  io_revision=<1..99, raised when Io's patches change>
#   patches/       *.patch, applied after Void's own patches
#                  lib32=yes  optional: also build for i686 and publish the
#                  -32bit packages (<sub>-holo-32bit), which then replace
#                  Void's <sub>-32bit as the 64-bit packages replace Void's
#   template.append  optional: template lines added at the end (build
#                  settings such as CFLAGS)
#   README.md      what the patches do, where they come from, upstream state
#
# gen copies Void's srcpkgs/<name> (template, files/, patches/) to
# srcpkgs/<name>-holo and rewrites the template:
#   - pkgname <name>-holo, every subpackage <sub> becomes <sub>-holo
#     (with its srcpkgs link), each replaces and provides the Void package
#     it stands for; provides carry the overlay's own revision (_101), so a
#     dependency such as MangoHud-32bit's "MangoHud>=0.8.4_2" still holds
#     after a revision bump in Void
#   - revision = Void's revision * 100 + io_revision, so both a rebuild in
#     Void (revision bump) and a change of Io's patches give a newer package
#   - a subpackage list set by the template itself (subpackages="...",
#     subpackages+=" ...") gets the new names as well
#   - ${pkgname} keeps meaning the Void name outside functions (distfiles,
#     wrksrc, ...) and in the build functions (do_install, post_install:
#     paths such as ${FILESDIR}/${pkgname}.conf); only inside a subpackage's
#     *_package() function it is left alone
# It stops (exit 2) when Void's version is not base_version: the patches
# have to be checked against the new version by hand, then base_version
# raised. A revision bump in Void only gives a new build.
#
# Void's -32bit package of an overlaid package stays Void's, unless the
# overlay sets lib32=yes: then build.sh builds it for i686 as well, and
# xbps-src turns that build into <sub>-holo-32bit for the multilib
# repository, with replaces and provides of Void's <sub>-32bit.

set -eu

IO_DIR="${IO_DIR:-$HOME/io-packages}"
VP_DIR="${VP_DIR:-$HOME/void-packages}"
OVERLAY="$IO_DIR/overlay"
BINPKGS="$VP_DIR/hostdir/binpkgs"

die() { echo "holo: $*" >&2; exit 1; }

# value of a plain "key=value" line of a template or overlay.conf
conf_get() {
    v=$(sed -n "s/^$2=//p" "$1" | head -1)
    v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
    echo "$v"
}

# 0: a = b, 1: a > b, 2: a < b
vercmp() {
    if command -v xbps-uhelper > /dev/null 2>&1; then
        set +e
        xbps-uhelper cmpver "$1" "$2"
        r=$?
        set -e
        case $r in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
    fi
    [ "$1" = "$2" ] && return 0
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && return 1
    return 2
}

overlays() {
    for d in "$OVERLAY"/*/; do
        [ -f "$d/overlay.conf" ] && basename "$d"
    done
}

void_template() {
    t="$VP_DIR/srcpkgs/$1/template"
    [ -f "$t" ] && [ ! -L "$VP_DIR/srcpkgs/$1" ] || return 1
    echo "$t"
}

subpkgs_of() {
    sed -n 's/^\([A-Za-z0-9._+-]*\)_package() *{.*$/\1/p' "$1"
}

# lib32=yes in overlay.conf: the overlay is built for i686 too
is_lib32() { [ "$(conf_get "$OVERLAY/$1/overlay.conf" lib32)" = yes ]; }

# Sets: base iorev vver vrev newrev state
inspect() {
    conf="$OVERLAY/$1/overlay.conf"
    base=$(conf_get "$conf" base_version)
    iorev=$(conf_get "$conf" io_revision)
    [ -n "$base" ] || die "$1: base_version missing in $conf"
    case "$iorev" in
        [1-9] | [1-9][0-9]) ;;
        *) die "$1: io_revision must be 1..99 (is '$iorev')" ;;
    esac
    if ! t=$(void_template "$1"); then
        state=missing; vver=-; vrev=-; newrev=-
        return
    fi
    vver=$(conf_get "$t" version)
    vrev=$(conf_get "$t" revision)
    case "$vver$vrev" in
        *'$'* | '') die "$1: cannot read version/revision from $t" ;;
    esac
    newrev=$((vrev * 100 + iorev))
    if vercmp "$vver" "$base"; then
        if [ -f "$BINPKGS/$1-holo-${vver}_$newrev.x86_64.xbps" ] &&
            { ! is_lib32 "$1" || [ -f "$BINPKGS/multilib/$1-holo-32bit-${vver}_$newrev.x86_64.xbps" ]; }; then
            state=built
        else
            state=build
        fi
    else
        state=review
    fi
}

cmd_check() {
    rc=0
    printf '%-24s %-14s %-12s %-18s %s\n' OVERLAY VOID BASE PACKAGE STATE
    for o in $(overlays); do
        inspect "$o"
        case $state in
            built) note="up to date" ;;
            build) note="to build" ;;
            review) note="REVIEW: Void is at $vver, patches are for $base"; rc=2 ;;
            missing) note="MISSING: no srcpkgs/$o in void-packages"; rc=2 ;;
        esac
        pv="-"
        [ "$newrev" != - ] && pv="${vver}_$newrev"
        printf '%-24s %-14s %-12s %-18s %s\n' "$o" "${vver}_$vrev" "$base" "$pv" "$note"
    done
    return $rc
}

cmd_tobuild() {
    for o in $(overlays); do
        inspect "$o"
        [ "$state" = build ] && echo "$o-holo"
    done
    return 0
}

# All overlays, or the one given. Fails when Void's template is missing:
# publish.sh prunes what this list lacks, so a short list must not pass.
cmd_names() {
    list=${1:-$(overlays)}
    for o in $list; do
        [ -f "$OVERLAY/$o/overlay.conf" ] || die "no overlay '$o'"
        t=$(void_template "$o") || die "$o: Void has no srcpkgs/$o in $VP_DIR"
        echo "$o-holo"
        for s in $(subpkgs_of "$t"); do
            echo "$s-holo"
        done
        # the -32bit packages xbps-src makes from the i686 build (those of
        # subpackages it does not make are skipped by publish.sh as unbuilt)
        if is_lib32 "$o"; then
            echo "$o-holo-32bit"
            for s in $(subpkgs_of "$t"); do
                echo "$s-holo-32bit"
            done
        fi
    done
}

cmd_gen() {
    o=$1
    [ -f "$OVERLAY/$o/overlay.conf" ] || die "no overlay '$o' (overlay/$o/overlay.conf)"
    inspect "$o"
    case $state in
        missing) die "$o: Void has no srcpkgs/$o (pull void-packages?)" ;;
        review)
            echo "holo: $o: Void is at $vver, the patches are made for $base." >&2
            echo "holo: check overlay/$o/patches against $vver, then set base_version=$vver" >&2
            exit 2
            ;;
    esac
    src="$VP_DIR/srcpkgs/$o"
    dst="$VP_DIR/srcpkgs/$o-holo"
    rm -rf "$dst"
    cp -a "$src" "$dst"
    if [ -d "$OVERLAY/$o/patches" ]; then
        mkdir -p "$dst/patches"
        for p in "$OVERLAY/$o/patches"/*.patch; do
            [ -f "$p" ] || continue
            # "zz-io-" sorts after Void's own patches
            cp "$p" "$dst/patches/zz-io-${p##*/}"
        done
    fi

    subs=$(subpkgs_of "$src/template" | tr "\n" " ")
    awk -v name="$o" -v ver="$vver" -v vrev="$vrev" -v newrev="$newrev" -v subs="$subs" '
        # replace every literal occurrence of f in str by t
        function lit(str, f, t,    out, i) {
            out = ""
            while ((i = index(str, f)) > 0) {
                out = out substr(str, 1, i - 1) t
                str = substr(str, i + length(f))
            }
            return out str
        }
        # $pkgname not followed by a name character
        function bare(str,    out, i, c) {
            out = ""
            while ((i = index(str, "$pkgname")) > 0) {
                c = substr(str, i + 8, 1)
                if (c ~ /[A-Za-z0-9_]/) {
                    out = out substr(str, 1, i + 7)
                } else {
                    out = out substr(str, 1, i - 1) name
                }
                str = substr(str, i + 8)
            }
            return out str
        }
        BEGIN {
            n = split(subs, s, " ")
            for (i = 1; i <= n; i++) if (s[i] != "") issub[s[i]] = 1
            for (sp in issub) sib[sp] = 1
            sib[name] = 1
            vr = "${version}_${revision}"
            infunc = 0; inpkg = 0; cursub = ""
        }
        # start of a top-level function: "name() {"
        /^[A-Za-z0-9._+-]+\(\) *\{/ {
            fn = $0; sub(/\(\).*/, "", fn)
            # in a build function, ${pkgname} means the Void name as well
            if (fn !~ /_package$/) $0 = bare(lit($0, "${pkgname}", name))
            if (fn ~ /_package$/) {
                sp = fn; sub(/_package$/, "", sp)
                if (sp in issub) {
                    $0 = sp "-holo_package()" substr($0, length(fn) + 3)
                    cursub = sp
                }
            }
            # a one-line function closes on the same line
            if ($0 !~ /\}[ \t]*$/) { infunc = 1; inpkg = (fn ~ /_package$/) }
            print; next
        }
        /^\}/ {
            if (cursub != "") {
                print "\t# Io overlay: stands in for Void'"'"'s " cursub
                print "\treplaces=\"${replaces:+$replaces }" cursub ">=0\""
                print "\tprovides=\"${provides:+$provides }" cursub "-${version}_${revision}\""
                cursub = ""
            }
            infunc = 0; inpkg = 0
            print; next
        }
        # dependencies between the packages of this template, at the exact
        # build version ("libnm-${version}_${revision}"), follow the rename
        {
            for (nm in sib) {
                $0 = lit($0, nm ">=" vr, nm "-holo>=" vr)
                $0 = lit($0, nm "-" vr, nm "-holo-" vr)
            }
        }
        # a subpackage list the template sets itself
        !infunc && /^[ \t]*subpackages\+?="/ {
            q1 = index($0, "\"")
            rest = substr($0, q1 + 1)
            q2 = index(rest, "\"")
            if (q2 > 0) {
                inner = substr(rest, 1, q2 - 1)
                after = substr(rest, q2)
                lead = (inner ~ /^[ \t]/) ? " " : ""
                nw = split(inner, w, /[ \t]+/)
                out = ""
                for (k = 1; k <= nw; k++) {
                    if (w[k] == "") continue
                    t = w[k]
                    if (t in issub) t = t "-holo"
                    out = out (out == "" ? "" : " ") t
                }
                $0 = substr($0, 1, q1) lead out after
            }
            print; next
        }
        !infunc && /^pkgname=/ { print "pkgname=" name "-holo"; next }
        !infunc && /^revision=/ { print "revision=" newrev; next }
        !inpkg { $0 = bare(lit($0, "${pkgname}", name)) }
        { print }
        END {
            print ""
            print "# Io overlay (overlay/" name "): Void'"'"'s " name " " ver "_" vrev " with Io'"'"'s"
            print "# patches, as a package of its own that replaces Void'"'"'s. Generated by"
            print "# overlay/holo.sh - edit overlay/" name ", not this file."
            print "replaces=\"${replaces:+$replaces }" name ">=0\""
            print "provides=\"${provides:+$provides }" name "-${version}_${revision}\""
        }
    ' "$src/template" > "$dst/template"
    if [ -f "$OVERLAY/$o/template.append" ]; then
        {
            echo
            echo "# from overlay/$o/template.append"
            cat "$OVERLAY/$o/template.append"
        } >> "$dst/template"
    fi
    if is_lib32 "$o"; then
        # xbps-src gives a -32bit package only the provides it reads from
        # $XBPS_STATEDIR/<pkg>-32bit-provides (do-pkg/00-gen-pkg.sh), and
        # no hook writes that file (pre-pkg/04-generate-provides.sh writes
        # <pkg>-provides only). Without it libgbm-holo-32bit would not
        # stand in for libgbm-32bit, and Void's -32bit packages depending
        # on it (gst-plugins-base1-32bit) would be broken. The file is
        # written here in the i686 build, before do-pkg reads it.
        {
            echo
            echo "# Io overlay (lib32=yes, overlay/holo.sh): provides of the -32bit packages"
            echo "_io_lib32_provides() {"
            echo "	[ \"\$XBPS_TARGET_MACHINE\" = i686 ] || return 0"
            echo "	local _n"
            echo "	for _n in $o $subs; do"
            echo "		echo \"\${_n}-32bit-\${version}_\${revision}\" > \"\${XBPS_STATEDIR}/\${_n}-holo-32bit-provides\""
            echo "	done"
            echo "}"
            echo "if declare -f post_install > /dev/null; then"
            echo "	eval \"_io_lib32_void_\$(declare -f post_install)\""
            echo "else"
            echo "	_io_lib32_void_post_install() { :; }"
            echo "fi"
            echo "post_install() {"
            echo "	_io_lib32_void_post_install"
            echo "	_io_lib32_provides"
            echo "}"
        } >> "$dst/template"
    fi
    sed -i "1s/.*/# Template file for '$o-holo' (generated from Void's '$o')/" "$dst/template"

    for s in $subs; do
        rm -rf "$VP_DIR/srcpkgs/$s-holo"
        ln -s "$o-holo" "$VP_DIR/srcpkgs/$s-holo"
    done
    echo "generated: $o-holo ${vver}_$newrev (Void $o ${vver}_$vrev + $(ls "$dst/patches" 2> /dev/null | grep -c '^zz-io-') patch(es))"
}

case "${1:-}" in
    check) cmd_check ;;
    gen) [ $# -eq 2 ] || die "usage: holo.sh gen <name>"; cmd_gen "$2" ;;
    names) cmd_names "${2:-}" ;;
    lib32) [ $# -eq 2 ] || die "usage: holo.sh lib32 <name>"; is_lib32 "$2" ;;
    tobuild) cmd_tobuild ;;
    *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
