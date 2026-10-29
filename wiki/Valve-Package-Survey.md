# SteamOS packages on Io

Every package of SteamOS that is specific to SteamOS or the Deck, and what
Io has in its place. The reference is **SteamOS 3.9.2** (Beta Candidate,
build 20260925.101), captured with `pacman -Q` on the same Deck on
2026-10-04; until then it was SteamOS 3.8.4 (versions of 3.8.4 are in
brackets where they differ). Generic Arch packages are left out. Contents
and sources of Io's packages are on [Packages](Packages).

`pkgcheck.sh` reports new versions on Valve's source mirror
(`jupiter-main`, `holo-main`); check it before acting on this page.

---

## Ported

| SteamOS 3.9.2 | On Io | Notes |
|---|---|---|
| `linux-neptune-72` 7.2.7 (3.8.4: `linux-neptune-616` 6.16.12) | `linux-neptune-72` 7.2.11 | Valve's `7.2.7-valve2` (SteamOS 3.9.3) with stable 7.2.11 merged in; built from the configuration Valve's package uses, see [Kernel](Kernel) |
| `jupiter-hw-support` 20260807.1 (20260327.1) | `deck-hw-support` 20260807.1 | Helpers under their `steamos-*` names, see [Helper status](Helper-Status); `steamos-update` behind them is Io's, with xbps. From 20260930.1 (SteamOS 3.9.3): the firmware updaters (`deck-firmware-updaters`) and the thumbstick and trigger calibration tools (`deck-controller-calibration`) |
| `steamos-manager` 26.4.1 (26.1.0) | `steamos-manager` (Valve's main of 2026-10-24) | Valve's daemon with runit support (fork [Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager), branch `runit`), see [Architecture](Architecture); until October 2026 Io's own implementation, `io-steamos-manager` |
| `ec-log` 0.1 (new) | `ec-log` 0.1 | The Steam Machine's EC log; runit service linked with a `down` file, started by SteamOS Manager |
| `jupiter-dock-updater-bin` | 20260811.01 (newest in jupiter-3.9) | Valve's dock updater as it is; untested without Valve's dock |
| `holo-session-selection` (new) | in `io-session` | `holo-session-select` (also as `steamos-session-select`, which Steam calls) with Io's desktop session, and SDDM's settings under its name `holo.conf`. Its `InputMethod=qtvirtualkeyboard` is SDDM's default and has no effect on a Wayland greeter |
| `galileo-mura` v0.10 | `galileo-mura` v0.10 | Started by the game mode session on the OLED (Valve: a user service); untested |
| `steam-jupiter-stable` 1.0.0.85-12 (-8) | `steam-jupiter` (-12) | |
| `steamdeck-dsp` 1.02 (0.91) | `steamdeck-dsp` 1.03 (Valve's main) | Sink loopbacks kept as in 0.91; 1.03's headphone suspend timeout |
| `jupiter-hibernate-disable` 0.1 (Valve's main, not on 3.9.2) | `jupiter-hibernate-disable` 0.1 | Core service instead of a oneshot unit; DMI from sysfs instead of `dmidecode` |
| `steamdeck-kde-presets` 3.9.4 (3.8.5) | 3.9.4 | |
| `jupiter-fan-control` 20260902.1 (20260422.2) | 20260902.1 | runit service |
| `vpower` 1.6.3 (1.5.7) | 1.6.3 | Patched hwmon path |
| `xdg-desktop-portal-gamescope` 0.1.38 (0.1.33) | 0.1.38 | |
| `xdg-desktop-portal-holo` 0.1.18 | 0.1.18 | Started by D-Bus, no systemd unit |
| `steamos-systemreport` 1.23 (0.16) | 1.23 | socklog and xbps instead of journal and pacman |
| `steamos-powerbuttond` 4.2 | 4.2 | |
| `steamos-networking-tools` 1.3 (1.2) | `holo-networkmanager-config` 1.0 | `steamos-wifi-set-backend` is left out, SteamOS Manager switches the backend itself. The NetworkManager defaults (on 3.9.2 in `steamos-customizations-jupiter`) come from Valve's `holo-networkmanager-config` of its main branch, without systemd-resolved; the connectivity check is `io-base`'s |
| `steamos-passwd` 1.0 | 1.0 | |
| `steamos-devkit-service` 0.20250916.0 | same | mDNS through Avahi |
| `steam-im-modules` 20240131 | same | |
| `steam_notif_daemon` 1.0.1 | 1.0.1 | sd-bus from libelogind; started by the game mode session |
| `drm_janitor` 0.0.4 | 0.0.4 | Run by the game mode session when gamescope exits |
| `cecd` 0.3.0 (0.2.0), `cec-audio-control` 0.1.0 | same | |
| `gpu-trace` 2.16 (2.14) | 2.17 (SteamOS 3.9.3) | runit service |
| `holo-zram-swap` 0.3 | 0.3 | runit service |
| `holo-earlyoom` 1.1 | 1.1 | |
| `holo-dmi-rules` 1.1 | 1.1 | Core service instead of tmpfiles |
| `holo-fstab-repair` 0.2 (0.1) | 0.2 | Runs at every boot |
| `holo-sudo` | same files | Checked against Valve's source for 3.8.4; unchanged since (Valve's main branch moves it to `holo-sudo-config`) |
| `holo-upower-config` 1.0 (not on 3.8.4) | 1.0 | With a fix for Valve's `yes`/`true` bug |
| `holo-realtek-firmware-toggles` 1.3-3 (not on 3.8.4) | 1.4 (SteamOS 3.9.3) | |
| `jupiter-firewall` 0.1 | 0.1 | ufw instead of firewalld |
| `steamos-customizations-jupiter` 20260827.2 | `steamos-tuning` (parts) | Sysctls, `modules-load.d`, early HID drivers, the initramfs modules of the `steam-deck` hook (as a dracut configuration), scheduler tunings, swap file; the A/B parts are not ported (see below). Valve's suspend-then-hibernate settings and swap helper; the hibernation guard, sleep hook and resume module next to them are Io's own |
| `steamos-tweak-mtu-probing` | in `steamos-tuning` | |
| `lib32-gamescope` 3.16.30 (3.16.15) | `gamescope-wsi-32bit` 3.17.0 | Only gamescope's WSI layer for 32-bit Vulkan games (frame limiter, bypass, HDR), built for i686 from gamescope's source |
| `ttf-twemoji-default` 13.1.0-2.5 | `ttf-twemoji-default` 13.1.0 | Built as Valve builds it: Fedora's Twemoji with the same glyphs removed and the same fontconfig file |
| `wireless-domain-setter` 1.2 (new) | `wireless-domain-setter` 1.2 | runit service instead of systemd; ends at once on the LCD ("no self-managed phy's"), apart from reloading `rtw89_8852cu` when Valve's USB streaming dongle is plugged in |
| `jupiter-legacy-support` | parts | `KillUserProcesses` (in `io-session`), `steam-web-debug-portforward`, and `steamos-update` (Io's own, with xbps behind it); Valve's own header calls the rest leftovers to be removed |
| `ibus-pinyin` 1.5.1, `pyzy` 1.1, `ibus-table-cangjie-lite` 1.8.8, `ibus-anthy` 1.5.14 (Valve's fork), `ibus-table` 1.17.19 (Arch), `ibus-hangul` (Arch) | `ibus-pinyin`, `pyzy`, `ibus-table-cangjie-lite`, `ibus-anthy-holo`, `ibus-table`, Void's `ibus-hangul` | Input methods for Steam's keyboard; same sources and versions |
| `mangohud` (Valve's build with `2c1dc52`), `networkmanager`, `bluez`, `kwin`, `xorg-xwayland`, `wpa_supplicant`, `iwd` (Valve's builds) | `MangoHud-holo`, `NetworkManager-holo`, `bluez-holo`, `kwin-holo`, `xorg-server-xwayland-holo`, `wpa_supplicant-holo`, `iwd-holo` | Void's packages with Valve's patches (and, for wpa_supplicant, some of its build options), through Io's overlay, see [Deviations](Deviations); some matter only on other hardware or with iwd as backend |

## Replaced by Io's own or Void's

| SteamOS 3.9.2 | On Io |
|---|---|
| `holo-plymouth-themes` | `io-branding` (Valve's logos are Valve's trademarks) |
| `holo-glibc-locales` | Void's `glibc-locales`; the image build generates the same set of locales |
| `gamescope` 3.16.30 (3.16.23) | Void's gamescope 3.17.0 (Valve's main has 3.17.0 too) |
| `gamemode`, `orca`, `speech-dispatcher`, `espeak-ng`, `sof-firmware`, `sdl2-compat`, `sdl3`, `knighttime`, `plasma-keyboard`, `noto-fonts-cjk` | Void's packages |
| `linux-firmware-neptune`, `amd-ucode-neptune` | Void's `linux-firmware` packages (the amplifier firmware, the Wi-Fi firmware and AMD's microcode are in them). Nothing the LCD needs is missing; Io's `deck-firmware` adds Valve's older `vangogh_vcn.bin` (AMD withdrew Void's) and Valve's Realtek Bluetooth firmware, see [Deviations](Deviations) |
| `mesa`, `vulkan-radeon` (Valve's builds) | `mesa-holo`: Void's Mesa 26.2.6 with Valve's patches, 64 and 32 bit, see [Deviations](Deviations) (*Graphics*, *Io overlay*) |
| `scx-scheds` | Void's `scx`, switched by SteamOS Manager through the runit service `scx` |
| `iio-sensor-proxy` (new in 3.9.2) | Not on Io: removed in Alpha 5, when SteamOS 3.8.4 did not have it either; Steam reads the light sensor itself. On 3.9.2 it runs, but nothing in game mode uses it |

## Not on Io

| SteamOS 3.9.2 | Why |
|---|---|
| `steamos-atomupd-client`, `atomupd-daemon`, `rauc`, `holo-desync`, `steamos-efi` | Atomic A/B system updates; Io updates with xbps behind Steam's `steamos-update` script and its own `Atomupd1` service, see [Deviations](Deviations), *System updates* |
| `steamos-reset` | Factory reset of the A/B system; Io has its own, `io-factory-reset` (see [Deviations](Deviations), *Factory reset*) |
| `dmemcg-booster`, `kcgroups`, `plasma-foreground-booster` | Driven by systemd's units and slices (`org.freedesktop.systemd1`); decided not to implement, see [Deviations](Deviations) |
| `steamos-log-submitter`, `jupiter-steamos-log-submitter` | Sends crash logs to Valve; would have to be retargeted first |
| `kdumpst`, `steamos-kdumpst-layer` | Kernel crash dumps, developer-facing; parked |
| `inputplumber` | Installed but not running on the Deck (3.8.4 and 3.9.2); steamos-manager uses it for other handhelds' controllers, which Io does not support |
| `dirlock` | Home directory encryption, filed with the A/B notes below (decided 2026-10-03) |
| `holo-keyring`, `holo-nix-offload`, `holo-nfs-utils-tmpfiles` | pacman keys, Nix store, NFS: nothing Io needs |
| `steamos-alias` (new in 3.9.2) | A pacman hook linking `steamos-*` names to the renamed `holo-*` helpers; Io keeps the `steamos-*` names Steam calls |
| `holo-debuginfod-config`, `holo-grant-cap-sys-nice` (new) | Debug symbols only for SteamOS builds; `cap_sys_nice` for SteamVR's compositor |
| `plasma-login-manager` (new) | Login manager installed but disabled (SDDM stays) |

---

## Guiding principle

Fewer dead stubs is good, but never at the cost of Io's own stability or
security. Most of this is "adapt", not "copy".

---

## A/B notes

What belongs to SteamOS's read-only A/B system and is not ported while Io
has a plain writable root and updates with xbps. It explains some of
Valve's choices and is the starting point if Io ever gets A/B updates.

- **`dirlock`** — encryption of the home directory with fscrypt,
  experimental and opt-in in SteamOS 3.8 (a PAM module unlocks it at
  login). Unnecessary for Io, even counterproductive, as long as Io itself
  has no A/B update system (decided 2026-10-03).
- **`offload`** — bind mounts that move writable paths of the read-only
  root to `/home/.steamos/offload` (`/opt`, `/root`, `/srv`,
  `/var/cache/pacman`, `/var/lib/docker`, `/var/lib/flatpak`, `/var/log`,
  `/var/tmp` and others; `/nix` comes from the separate `holo-nix-offload`).
  Not needed with a writable root.
- **Hibernation hooks** — `hibernate-post.sh` resets the A/B boot counter
  after resuming from hibernation (`steamos-bootconf`); its other step,
  `hibernate-swap-helper.sh cleanup`, is part of Io's sleep hook
  `io-hibernate` (`steamos-tuning`). The rest of the
  sleep setup is on [Deviations](Deviations) (*System services*);
  `modules-reload.sh` only concerns the OLED's Wi-Fi (`ath11k`), and the
  Deck no longer hibernates (`jupiter-hibernate-disable`).
- **Valve's newer `steamos-customizations`** (after 3.8.4) is mostly A/B
  work: `holo-sync-var` (syncing `/var` between slots, fallbacks), RAUC
  options, `first-boot` activation, boot attempt counters.

From `steamos-customizations-jupiter`:

- `atomic-update/` — RAUC integration, the `steamos-atomupd` client,
  systemd units, tmpfiles rules
- `chainloader/` and `grub/grub.d/30_efi-prober.in` — slot switching
  between the A/B partition sets, and probing removable media for SteamOS's
  recovery chainloader
- `initrd/holo-etc-overlay.ash` — mounts `/etc` as a writable overlay on the
  read-only root; `holo-factory-reset.ash`, `holo-var.ash`,
  `holo-var-lib-modules.ash` handle reset and `/var` at the same stage

`holo-fstab-repair` shows the consequence: on SteamOS `fstab` lives in the
`/etc` overlay, and Valve's unit runs the repair only when the overlay's
copy was changed. Io's `/etc` is plain and persistent, and Io runs it at
every boot. If Io ever gets an atomic `/etc`, revisit that.

Also read (2026-10-03): `swap/` (Io already has Valve's newest swap file
script, which re-creates a broken swap file), `offload/` and
`misc/sleep.conf.d` (above).

---

## Not taken

- `rnnoise-ladspa` stays 1.10: upstream 1.21 raised the LADSPA plugin's
  default voice threshold from about 25 % to about 74 %, and Valve's filter
  chain sets none; the microphone would cut more.

---

## Evaluated 2026-10-04 (name check of Valve's repositories)

Names in Valve's `jupiter-*` and `holo-*` repositories this page did not
mention before, checked against SteamOS 3.9.2 and Void.

**Skipped:** `fremont-hw-support` (Steam Machine BIOS only),
`usbhid-gadget-passthru` (USB device mode, developer tool),
`fwupd-minimal` (Deck BIOS goes through `jupiter-biosupdate`; Void has
`fwupd`), `breakpad` and `umr` (log submitter only), `renderdoc-minimal`
(developer tool), `rtl88x2ce-dkms` (the LCD uses the kernel's `rtw88`),
other kernel series, and the old CEC path (`wakehook`,
`plasma-remotecontrollers`).

**Checked, not needed** (2026-10-10): `zenity-gtk3` — Void's `zenity` 4
behaves as Valve's 3.44 does: in game mode neither shows a dialog while
Steam is running, in the desktop both do; `inputattach-cec-units` — its
udev rules only match Pulse-Eight and RainShadow USB-CEC adapters, and
the JSAUX dock used for testing contains none (`lsusb` on Io and SteamOS).

**Not installed on SteamOS, not evaluated yet:** Valve's repair, recovery
and media creation tools (`steamos-repair-tool-git`,
`steamos-repair-backend-git`, `steamos-media-creation-git`, `calamares`
with `calamares-settings-steamos-git`), `steamfs-git`, `foxnet`,
`foxnetstatsd`, `jupiter-validation-tools`, `kdump-steamos`, `libevdi`,
`paru`, Valve's image and packaging tools; and the small configuration
packages of Valve's main branch (`holo-plymouth-config`,
`holo-desync-config`, `holo-sudo-config` with the same files as Io's
`holo-sudo`, `holo-config-mtu-probing` with the file Io already has in
`steamos-tuning`).

**Arch packages Valve rebuilds with patches:** Io takes Valve's changes as
configuration where that is enough (Valve's Bluetooth settings), and
otherwise builds Void's package with Valve's patches as an overlay package
(see [Deviations](Deviations), *Io overlay*).
Watched: PipeWire's next major release (Bluetooth profiles, dock HDMI
fixes).
