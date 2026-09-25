# Packages

All packages live in [io-packages/srcpkgs](https://github.com/Lolzen/io-packages/tree/main/srcpkgs)
and are published to the [io-repo](https://github.com/Lolzen/io-repo/releases/tag/current)
release. `io-desktop` pulls in everything; `mkimg.sh` installs nothing
else. Differences to Valve's originals are listed in [Deviations](Deviations).

## Io's own

| Package | Contents |
|---|---|
| `io-desktop` | Metapackage: the whole system, including Void base, Steam, gamescope, PipeWire, KDE Plasma and all packages below |
| `io-base` | Repository configuration, elogind drop-in, dracut configuration (amdgpu, Plymouth), polkit rules, ALSA routed through PipeWire, `timedatectl` replacement, shutdown hook closing SSH sessions |
| `io-session` | Login and sessions: `io-autologin` service, `io-start`, `io-gamemode`, `io-plasma`, `steamos-session-select`, session logs (`io-devmode`), `io-grow-storage` and its desktop entry, gamescope capability core service |
| `io-steamos-manager` | Io's implementation of Valve's SteamOS Manager D-Bus service, root and session half |
| `io-branding` | Logo, Plymouth boot splash theme, fastfetch configuration |

## Ported from Valve

| Package | Upstream | Contents |
|---|---|---|
| `linux-neptune-72` | `linux-integration` (7.2.4) | Steam Deck kernel: Void's base configuration plus Valve's `config-neptune` fragment, and one patch generated from Valve's tree against the kernel.org tarball |
| `deck-hw-support` | `jupiter-hw-support` 20260807.1 | Polkit helpers, udev rules, hwsupport scripts, Valve's cursor theme |
| `jupiter-fan-control` | `jupiter-fan-control` | Valve's fan daemon, as a runit service |
| `steamos-powerbuttond` | `steamos-powerbuttond` 4.2 | Power button daemon |
| `steamos-systemreport` | `steamos-systemreport` 1.23 | System report for bug reports (socklog, session logs, xbps) |
| `steamos-networking-tools` | `steamos-networking-tools` 1.2 | Wi-Fi backend switch (runit port), Valve's NetworkManager defaults, connectivity check |
| `steamdeck-dsp` | `steamdeck-dsp` 1.02 | Speaker and microphone DSP (Faust LV2 plugins), UCM, PipeWire/WirePlumber configuration, the filter chain's own PipeWire instance, and Io's WirePlumber script for the ALSA loopbacks |
| `xdg-desktop-portal-gamescope` | `xdg-desktop-portal-gamescope` | Portal backend for screenshots and recording in game mode |
| `holo-zram-swap` | `holo-zram-swap` 0.3 | zram swap service with Valve's values, zswap off |
| `holo-earlyoom` | `holo-earlyoom` 1.1 | earlyoom configuration and SteamAppId-aware kill logging |
| `steamos-tuning` | `steamos-customizations-jupiter` | Sysctls, early HID drivers, Valve's scheduler tunings (debugfs), 1 GiB swap file, hibernation guard, X11 virtual display size |
| `holo-dmi-rules` | `holo-dmi-rules` 1.1 | DMI serial number permissions |
| `holo-fstab-repair` | `holo-fstab-repair` 0.2 | Disables invalid SD card fstab lines ([SteamOS#1208](https://github.com/ValveSoftware/SteamOS/issues/1208)) |
| `steamos-passwd` | `steamos-passwd` | Password setter used by Steam's UI |
| `steam-jupiter` | `steam-jupiter-stable` 1.0.0.85 | Valve's Deck packaging of Steam, replacing Void's `steam`: preinstalled client on the Deck branch, Valve's wrapper, udev rules for input, status LED and wakeup |
| `steam-im-modules` | `steam-im-modules` 20240131 | Steam's on-screen keyboard as input method for GTK 3/4 and Qt 5 |
| `steamdeck-kde-presets` | `steamdeck-kde-presets` 3.9.4 | Valve's Plasma defaults: Steam in the desktop, Vapor theme, power and locker settings, KWallet, IBus, *Return to Gaming Mode* |
| `vpower` | `vpower` 1.6.3 | Valve's battery daemon: metrics for Steam, controlled shutdown at 0.5 %. Patched to find the charge limit file |
| `holo-upower-config` | `holo-upower-config` 1.0 | Hands UPower's critical battery action to vpower (with a fix for Valve's `yes`/`true` bug) |

## From elsewhere

| Package | Upstream | Contents |
|---|---|---|
| `rnnoise-ladspa` | [werman/noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice) 1.10 | RNNoise LADSPA plugin for `steamdeck-dsp`'s filter chain |

## Upstream sources

Valve's source mirror is
`steamdeck-packages.steamos.cloud/archlinux-mirror/sources/`, split into
`jupiter-main` (device-specific) and `holo-main` (the general OS layer).
The former GitLab mirror at `gitlab.com/evlaV` was shut down in August
2025; `github.com/evlaV` succeeds it. Existing distfile URLs still resolve,
but new versions should come from Valve's own mirror.

`pkgcheck.sh` fetches both listings, keeps the newest version of each package
in `docs/`, and reports what changed since the last run.

The kernel is not maintained as a fork: Valve's delta is a single patch
against the official tarball plus Valve's configuration fragment. A version
bump means a new patch and a new fragment.
