# plymouth-holo

Replaces Void's `plymouth`, `plymouth-devel` and `plymouth-data`.

Valve's patches from plymouth 22.02.122-7.7 (SteamOS 3.9.5, holo-3.9), in
Valve's order. Void ships the same version without them.

| Patch | Valve's file | What |
|---|---|---|
| 01 | `0001-defaults-set-DeviceScale-1` | `DeviceScale=1` in plymouthd's defaults |
| 02 | `0001-Revert-drm-Honour-screen-rotation-when-detecting-HiD` | HiDPI detection ignores the panel rotation (the Deck's panel is rotated) |
| 03 | `0010-Close-the-FB-if-possible-to-keep-the-image-on-the-sc` | **The DRM renderer keeps its last image on screen when plymouth quits with `--retain-splash`** (Collabora) |
| 04 | `0011-retain-splash-when-quitting` | `plymouth-quit.service` quits with `--retain-splash` (systemd unit, unused on Io; `io-sddm` already quits that way) |
| 05-09 | `0012`-`0016` | BGRT image, raw pixel reading, head scraping (DRM), `scrape_display` image for scripts (Valve's update splash) |
| 10 | `0020-Suppress-unimportant-unused-result-warnings` | build warnings |
| 11 | `0001-script-Add-System-script-plugin` | script themes can ask for the product/board (Valve's themes); changes Makefile.am, hence `autoreconf` in `template.append` |
| 12 | `0001-drm-set-connector-content-type-to-Game` | content type "Game" on the connector (TVs switch to game mode) |
| 13 | `0002-drm-clear-connector-HDR_OUTPUT_METADATA` | HDR output metadata cleared (TVs leave HDR mode) |
| 14 | `0001-src-plymouthd.defaults-Increase-DeviceTimeout-from-8` | `DeviceTimeout=14` (seamless boot with slower device detection) |

Left out: Arch's mkinitcpio/systemd shutdown patch, the systemd unit
patches (`plymouth-quit.service.in`, `plymouth-systemd-units`) and
`plymouthd.conf.patch` (a comment).

Why: with 03, the splash stays on screen until SDDM and gamescope take the
display over, instead of a black screen in between (seen with the animated
splash on `test-torus-splash`, 2026-10-29). The rest is Valve's state of
plymouth.

`INSTALL` rebuilds the initramfs on an update: plymouthd runs from it.
holo.sh copies an overlay's `INSTALL` into the generated package.

All 14 apply to 22.02.122 after Void's two patches (12 cleanly, two with
fuzz); built (autoreconf, Void's configure options) on 2026-10-29.

Way back: Valve only; none is upstream (plymouth 24 reworked the renderer).
Stays while Void ships 22.02.
