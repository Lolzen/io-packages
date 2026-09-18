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

## Audio, memory, and OOM handling (Alpha 2)

| Package | Contents |
|---|---|
| `steamdeck-dsp` | Valve's Jupiter/LCD speaker and microphone DSP — Faust LV2 plugins, UCM profiles, PipeWire/WirePlumber hardware-profile fragments, a microphone loopback for Steam's mic selection. Galileo (OLED)-specific parts stripped |
| `rnnoise-ladspa` | werman/noise-suppression-for-voice, built from source (LADSPA target only, no VST/JUCE dependency) — the actual RNNoise plugin `steamdeck-dsp`'s filter chain calls; Void's `NoiseTorch` package is GUI-only and doesn't ship this |
| `holo-earlyoom` | Valve's `earlyoom` tuning (SteamOS's kill thresholds, SteamAppId-aware kill logging) — depends on Void's `earlyoom`, supplies its runit `conf` file |
| `holo-zram-swap` | Valve's ZRAM tuning (50% RAM, zstd, priority 100) — depends on Void's `zramen`, supplies its runit `conf` file instead of the systemd-only `zram-generator` upstream ships |

## Small system tuning, ported today

| Package | Contents |
|---|---|
| `steamos-tuning` | Valve's sysctl/limits gaming tweaks — TCP MTU probing, faster TCP port reuse, scheduler slice, split-lock mitigation disabled, raised `vm.max_map_count`, Proton's `nice` ceiling |
| `steamos-passwd` | Stdin-driven wrapper around `passwd`, meant for Steam's own UI to call when setting a device password |
| `holo-dmi-rules` | Makes the DMI serial number readable without root — Void has no `tmpfiles.d` equivalent, so this runs as a boot-time core-service `chmod`/`chgrp` instead |
| `holo-fstab-repair` | Disables invalid `/dev/mmcblk*` fstab entries that block UDisks2 from mounting SD cards ([ValveSoftware/SteamOS#1208](https://github.com/ValveSoftware/SteamOS/issues/1208)) — currently a no-op since SD/USB automount isn't enabled |
| `holo-plymouth-themes` | Valve's "holo" Plymouth boot-splash theme, Jupiter/LCD logo included — package builds and installs the theme, not yet wired into dracut/GRUB to actually display at boot |