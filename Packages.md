# Packages

| Package | Contents |
|---|---|
| `linux-neptune` | Kernel 6.15.8 from the kernel.org tarball plus Valve's patch set and the Deck config fragment |
| `deck-firmware-cirrus` | CS35L41 DSP firmware for the speaker amplifiers |
| `deck-hw-support` | Valve's polkit helpers, udev rules and hwsupport scripts, trimmed and stubbed. **Frozen at 20250728.1**, see [Pitfalls](Pitfalls) |
| `jupiter-fan-control` | Valve's fan daemon, unmodified, wrapped in a runit service |
| `steamos-powerbuttond` | Valve's power button daemon, systemd unit replaced |
| `io-base` | Repository config, elogind drop-in, dracut snippet, polkit rules, `timedatectl` replacement |
| `io-branding` | os-release, ASCII and SVG logo, fastfetch config |
| `io-session` | Game mode startup, session switching, autologin service, PipeWire/WirePlumber autostart symlinks |
| `io-volumed` | Volume key handler (Steam shows the OSD but does not set the level) |
| `io-desktop` | Metapackage tying everything together |
| `inputplumber` | Packaged and working, **but not enabled** — see [Pitfalls](Pitfalls) |

The kernel is not maintained as a fork. Valve's delta is a single patch against
the official tarball, and the config fragment comes unchanged from Valve's
sources. A version bump means a new tag, a new patch and a new fragment.

## Upstream sources

Valve's authoritative source mirror is
`steamdeck-packages.steamos.cloud/archlinux-mirror/sources/`, split into
`jupiter-main` (device-specific) and `holo-main` (the general OS layer). Both
carry signature files.

The GitLab mirror at `gitlab.com/evlaV` was shut down in August 2025;
`github.com/evlaV` is the successor. Existing distfile URLs still resolve, but
prefer Valve's own mirror when bumping versions.

`pkgcheck.sh` fetches both listings, keeps the newest version of each package
in `docs/`, and reports what changed since the last run. Useful for spotting
upstream updates without trawling directory listings by hand.