# Io overlay: Void packages with Io's patches

Some Void packages need a patch that Void does not carry, mostly one of
Valve's from SteamOS. Io builds such a package as a package of its own,
`<name>-holo`, that replaces Void's `<name>`:

- the name cannot collide with Void's, so the repository order does not
  matter (xbps takes a package from the first repository that has it, and
  Void's repositories come before Io's);
- a Void update of `<name>` never replaces the patched package on the Deck;
- the `-holo` suffix shows at a glance which packages are Io's stand-ins.
  (Packages named `holo-*`, such as `holo-sudo`, are Valve's own packages
  with Valve's names; they are not overlays.)

## How it works

An overlay is a directory `overlay/<name>/`, named after the Void package:

| File | Content |
|---|---|
| `overlay.conf` | `base_version`: the Void version the patches are made for. `io_revision`: 1..99, raised whenever the patches change |
| `patches/*.patch` | applied after Void's own patches (as `zz-io-*.patch`) |
| `README.md` | what each patch does, where it comes from, upstream state, way back |

`overlay/holo.sh gen <name>` copies Void's `srcpkgs/<name>` in
void-packages to `srcpkgs/<name>-holo`, adds the patches and rewrites the
template: `pkgname` and every subpackage get the `-holo` suffix; each one
`replaces` the Void package it stands for and `provides` it, at the
overlay's own revision. The revision is Void's revision × 100 +
`io_revision` (Void's `0.8.4_1` + `io_revision=1` gives `0.8.4_101`), so a
rebuild in Void and a change of Io's patches both give a newer package.
Nothing generated is committed: the template always follows Void's current
one.

`build.sh` does this by itself:

```
./build.sh -p MangoHud-holo      generate from Void's MangoHud, build, publish
./build.sh -p --overlays         every overlay whose current build is missing
overlay/holo.sh check            status of all overlays, changes nothing
```

`build.sh` pulls void-packages first, then for each overlay:

1. Void's version equals `base_version` → generate, build, publish.
2. Void only bumped the revision → same, with the new revision.
3. Void's version differs from `base_version` → **not built**, the run ends
   with exit status 2 ("REVIEW"). Check the patches against Void's new
   version (still needed? still apply?), then set `base_version` to it, or
   remove the overlay (see "Way back").

`publish.sh` publishes the overlay packages with Io's own; their names come
from `holo.sh names`.

Only x86_64 is built: Void's `-32bit` package of an overlaid package stays
Void's (its dependency on the 64-bit package is met by the `provides`).

After a Void update, run `./build.sh -p --overlays` before updating the
Deck: between a Void revision bump and Io's rebuild, Void's `-32bit`
package can ask for a newer revision than the overlay provides.

## Way back

When Void's package contains the fix (or the patch is dropped), remove the
overlay and switch the dependency in `io-desktop` back to Void's name.
On the Deck, Void's package does not replace `<name>-holo` by itself: an
Io package (for instance `io-base`) gets `replaces="<name>-holo>=0"` for
one release, so the update removes the overlay package and installs Void's.

## Overlays

| Overlay | Replaces | Void base | Patches | Upstream | Since |
|---|---|---|---|---|---|
| [MangoHud](MangoHud/README.md) | MangoHud, MangoHud-mangoapp | 0.8.4 | mangoapp renders once per game frame (`2c1dc52`) | master, not in 0.8.4 | 2026-10-05 |

## Hand-written stand-ins

Packages that replace a Void package but are not built from Void's
template (other source, other version), in `srcpkgs/`:

| Package | Replaces | Why |
|---|---|---|
| `ibus-anthy-holo` | ibus-anthy (Void 1.5.16) | Valve's fork of 1.5.14 (bjj/ibus-anthy `0962741`) with the settings Steam's keyboard writes; Valve's commits do not apply to 1.5.16. Was `ibus-anthy-jupiter` |
| `steam-jupiter` | steam | Valve's Steam package for the Deck, Valve's name |

## Candidates for review

Valve patches that were set aside because each would have cost a fork of
a Void package (evaluation of 2026-10-04,
`claude/reports/eval-patched-arch.md` in the project). With the overlay a
fork is cheap; these deserve a second look:

| Package | Valve patch | Earlier verdict |
|---|---|---|
| NetworkManager (Void 1.56.0) | Wi-Fi: scan only the last-associated frequency after resume (MR 2514, open) | worth having; measure reconnect time after resume first |
| bluez (Void 5.86) | Switch Pro v1 disconnect fix; LE resolving-list fix (Steam Controller and suspend) | optional, small |
| xorg-server-xwayland (Void 24.1.13) | 2 reverts for a seamless Steam start under gamescope | dropped with 4.7 (black screen not pursued) |
| kwin (Void 6.7.5) | 0006 + 0011: Steam keyboard input through libei in the desktop | only if the Steam keyboard misbehaves in the desktop |
| mesa (Void 26.2) | DRI3 frame limiter for OpenGL (`GAMESCOPE_LIMITER_FILE`), RADV game fixes | decided 2026-10-03: stay with Void's Mesa; large build, needs 32-bit too |
| iwd (Void 3.12) | 3 station fixes | irrelevant while wpa_supplicant is the backend |
| wpa_supplicant (Void 2.12) | SAE wrong-password detection; 6 GHz rescans | LCD has no 6 GHz; SAE low priority |

Not candidates (upstream already, Steam Machine/OLED only, or systemd
only): see the evaluation report.
