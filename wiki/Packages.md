# Packages

All packages live in [io-packages/srcpkgs](https://github.com/Lolzen/io-packages/tree/main/srcpkgs)
and are published to the [io-repo](https://github.com/Lolzen/io-repo/releases/tag/current)
release. `io-desktop` pulls in everything; the image build installs nothing
else. Differences to Valve's originals are listed in [Deviations](Deviations).

## Io's own

| Package | Contents |
|---|---|
| `io-desktop` | Metapackage: the whole system. It stands in for Void's `base-system`, which would pull in Void's own kernel next to `linux-neptune-72` (that kernel does not boot the Deck), and lists base-system's other packages itself. Plus Steam, gamescope, PipeWire with `wireplumber-elogind`, KDE Plasma with `plasma-keyboard`, vim and nano, `wireless-regdb`, `gstreamer1-pipewire`, IBus with the engines for Steam's keyboard and the Noto CJK fonts, and all packages below, including the overlay packages in place of Void's |
| `io-base` | Repository configuration (and keeping elogind's D-Bus activation file out on updates), elogind drop-in (the power key is left to `steamos-powerbuttond`), dracut configuration (SD card modules and amdgpu, Plymouth), ALSA routed through PipeWire, `timedatectl` replacement, `/usr/share/i18n/SUPPORTED`, shutdown hook closing SSH sessions, SteamOS's Bluetooth settings (`/usr/share/io/bluetooth/main.conf`, read by `bluetoothd`), GRUB without its menu (`/etc/default/grub`, set by `INSTALL`), `io-bootnext` (*Restart* starts Io again, see [Architecture](Architecture)) |
| `io-session` | Login and sessions: SDDM service `io-sddm` and its settings, session files, `io-start`, `io-gamemode`, `io-plasma`, `steamos-session-select`, memlock limit, session logs (`io-devmode`), `io-grow-storage` and its desktop entry, capability core service (gamescope, kwin), `KillUserProcesses` for elogind. Game mode as Valve's session: Valve's `steam-launcher` and short-session tracker, the low-disk check before start, the HDMI-CEC daemons, Steam's notification daemon, `ibus-daemon` for Steam's keyboard, `drm_janitor` when gamescope exits. The desktop keeps game mode's brightness |
| `io-steamos-manager` | Io's implementation of Valve's SteamOS Manager D-Bus service, root and session half, including the screen reader (Orca), HDMI-CEC (`HdmiCec1`, `HdmiCec2`), download mode with Valve's fan speed and storage trimming as jobs (`Storage1`); runit service `scx` for the LAVD scheduler. System updates: `/usr/bin/steamos-update`, `/usr/libexec/io/io-update` and `com.steampowered.Atomupd1` on the root half, with xbps behind them |
| `io-branding` | Logo, Plymouth boot splash theme, the picture for Steam's update screen, fastfetch configuration |
| `io-release` | `os-release` and `lsb_release`, which Steam shows under Settings → System; kept in place after `base-files` updates |

## Ported from Valve

| Package | Upstream | Contents |
|---|---|---|
| `linux-neptune-72` | `linux-integration` (7.2.7) | Steam Deck kernel: the kernel.org tarball with one patch generated from Valve's tree; configuration in layers (Void, the configuration Valve's package builds from, `config-neptune`, Io's overrides), see [Kernel](Kernel) |
| `deck-firmware` | `linux-firmware-neptune` (files) | Valve's older `amdgpu/vangogh_vcn.bin` and Valve's Realtek Bluetooth firmware, in `/usr/lib/firmware/updates` (the rest comes from Void's `linux-firmware`) |
| `deck-hw-support` | `jupiter-hw-support` 20260807.1 | Polkit helpers (the `steamos-update` helper calls `io-steamos-manager`'s script), udev rules, hwsupport scripts, Valve's cursor theme; automount through `io-detach`, Io's rule hiding the internal SSD, `io-root-disk`; pulls in `udisks2` |
| `jupiter-fan-control` | `jupiter-fan-control` | Valve's fan daemon, as a runit service |
| `steamos-powerbuttond` | `steamos-powerbuttond` 4.2 | Power button daemon |
| `steamos-systemreport` | `steamos-systemreport` 1.23 | System report for bug reports (socklog, session logs, xbps) |
| `steamos-networking-tools` | `steamos-networking-tools` 1.3 | Wi-Fi backend switch (runit port), Valve's NetworkManager defaults, connectivity check |
| `steamdeck-dsp` | `steamdeck-dsp` 1.02 | Speaker and microphone DSP (Faust LV2 plugins), UCM, PipeWire/WirePlumber configuration, the filter chain's own PipeWire instance, and Io's WirePlumber script for the ALSA loopbacks (sources and sinks, as on SteamOS 3.8.4) |
| `xdg-desktop-portal-gamescope` | `xdg-desktop-portal-gamescope` 0.1.38 | Portal backend for screenshots and recording in game mode; its `gamescope-portals.conf` puts the holo portal first, as on SteamOS |
| `xdg-desktop-portal-holo` | `xdg-desktop-portal-holo` 0.1.18 | Portal backend for game mode: Settings (color scheme, contrast, accent color), app chooser, e-mail, lockdown; started by D-Bus |
| `steam_notif_daemon` | `steam_notif_daemon` 1.0.1 | Takes desktop notifications in game mode and passes them to Steam |
| `drm_janitor` | `drm_janitor` 0.0.4 ([zzag/drm_janitor](https://github.com/zzag/drm_janitor)) | Resets the display state gamescope leaves behind when game mode ends |
| `gpu-trace` | `gpu-trace` 2.16 ([lostgoat/gpu-trace](https://github.com/lostgoat/gpu-trace)) | Steam's system tracing (developer settings), runit service |
| `holo-zram-swap` | `holo-zram-swap` 0.3 | zram swap service with Valve's values, zswap off |
| `holo-earlyoom` | `holo-earlyoom` 1.1 | earlyoom configuration and SteamAppId-aware kill logging |
| `steamos-tuning` | `steamos-customizations-jupiter` 20260827.2 | Sysctls, early HID drivers, NTSync loaded at boot, Valve's scheduler tunings (debugfs), 1 GiB swap file, X11 virtual display size, Proton's nice limit, `EDITOR=vim`, `LIBVA_DRIVER_NAME=radeonsi`; Io's own: the hibernation guard and the open-file limit SteamOS gets from systemd |
| `holo-dmi-rules` | `holo-dmi-rules` 1.1 | DMI serial number permissions |
| `holo-fstab-repair` | `holo-fstab-repair` 0.2 | Disables invalid SD card fstab lines ([SteamOS#1208](https://github.com/ValveSoftware/SteamOS/issues/1208)) |
| `steamos-passwd` | `steamos-passwd` | Password setter used by Steam's UI |
| `steam-jupiter` | `steam-jupiter-stable` 1.0.0.85 | Valve's Deck packaging of Steam, replacing Void's `steam`: preinstalled client on the Deck branch, Valve's wrapper, udev rules for input, status LED and wakeup; 32-bit PipeWire with all its plugins |
| `steam-im-modules` | `steam-im-modules` 20240131 | Steam's on-screen keyboard as input method for GTK 3/4 and Qt 5 |
| `steamdeck-kde-presets` | `steamdeck-kde-presets` 3.9.4 | Valve's Plasma defaults: Steam in the desktop, Vapor theme, power and locker settings, KWallet, IBus, *Return to Gaming Mode* |
| `vpower` | `vpower` 1.6.3 | Valve's battery daemon: metrics for Steam, controlled shutdown at 0.5 %. Patched to find the charge limit file |
| `holo-upower-config` | `holo-upower-config` 1.0 | Hands UPower's critical battery action to vpower (with a fix for Valve's `yes`/`true` bug) |
| `holo-sudo` | `holo-sudo` | Valve's sudoers files: `wheel`, `sudo`, `no-fqdn` |
| `holo-realtek-firmware-toggles` | `holo-realtek-firmware-toggles` 1.3-3 | Valve's toggles for Realtek rtw89 USB Wi-Fi sticks |
| `jupiter-firewall` | `jupiter-firewall` 0.1 | Valve's firewall rules, with ufw and `plasma-firewall` (Void has no firewalld); runit service |
| `cecd` | `cecd` 0.3.0 | Valve's HDMI-CEC daemon; group rules for `/dev/cec*` and `/dev/uinput` |
| `cec-audio-control` | `cec-audio-control` 0.1.0 | TV volume and mute over HDMI-CEC for PipeWire |
| `steamos-devkit-service` | `steamos-devkit-service` 0.20250916.0 | Service for the SteamOS Devkit Client; mDNS through Avahi (patch); runit service |
| `ibus-table-cangjie-lite` | `ibus-table-cangjie-lite` 1.8.8 (Valve's fork of ibus-table-chinese) | CangJie and Quick tables for Steam's keyboard, trimmed to the characters Noto Sans CJK can show |
| `ibus-anthy-holo` | `ibus-anthy` 1.5.14 (Valve's fork) | Japanese input for Steam's keyboard, with the settings Steam writes; replaces Void's `ibus-anthy` |
| `gamescope-wsi` (published as `gamescope-wsi-32bit`) | gamescope 3.16.30 (SteamOS: `lib32-gamescope`) | gamescope's Vulkan WSI layer for 32-bit games (frame limiter, bypass, HDR), built for i686; only the layer, not gamescope |

## From elsewhere

| Package | Upstream | Contents |
|---|---|---|
| `rnnoise-ladspa` | [werman/noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice) 1.10 | RNNoise LADSPA plugin for `steamdeck-dsp`'s filter chain |
| `steam-web-debug-portforward` | Io, after Valve's `jupiter-legacy-support` | Steam's CEF debugging port on the network (8081 → 8080), runit service with `socat` |
| `pyzy` | [openSUSE/pyzy](https://github.com/openSUSE/pyzy) 1.1 (Valve's source archive) | Pinyin and Bopomofo conversion library for `ibus-pinyin` |
| `ibus-pinyin` | [ibus/ibus-pinyin](https://github.com/ibus/ibus-pinyin) 1.5.1 | The *pinyin* and *bopomofo* engines Steam's keyboard asks for (Void's `ibus-libpinyin` has other engine names) |
| `ibus-table` | [kaio/ibus-table](https://github.com/kaio/ibus-table) 1.17.19 | Engine for table-based input methods (CangJie, Quick) |

## Overlay packages

Void packages with Io's (Valve's) patches, generated at build time from
Void's current template and published as `<name>-holo`, replacing Void's
package (see [Building](Building) and [Deviations](Deviations), *Io
overlay*). They live in io-packages' `overlay/`, not in `srcpkgs/`.

| Package | Replaces | Patches |
|---|---|---|
| `MangoHud-holo`, `MangoHud-mangoapp-holo` | `MangoHud`, `MangoHud-mangoapp` | mangoapp draws once per game frame |
| `NetworkManager-holo`, `libnm-holo`, `NetworkManager-devel-holo` | Void's NetworkManager packages | Wi-Fi after resume scans the last frequency only |
| `bluez-holo`, `libbluetooth-holo`, ... | Void's bluez packages | LE resolving list fix, Switch Pro Controller |

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
against the official tarball. How the patch and the configuration come
about, and what to do on a kernel update, is on [Kernel](Kernel).

What SteamOS 3.9.2 runs of Valve's packages, and what Io has in their place,
is on [SteamOS packages](Valve-Package-Survey).
