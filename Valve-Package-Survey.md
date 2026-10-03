# SteamOS packages on Io

Every package of SteamOS 3.8.4 that is specific to SteamOS or the Deck, and
what Io has in its place. The list comes from the reference capture
(`pacman -Q` on SteamOS 3.8.4, same Deck); generic Arch packages are left
out. Versions in brackets are the ones SteamOS 3.8.4 runs. Where Io
builds a newer version, [Deviations](Deviations) (*Versions*) explains the
rule; contents and sources of Io's packages are on [Packages](Packages).

`pkgcheck.sh` reports new versions on Valve's source mirror
(`jupiter-main`, `holo-main`); check it before acting on this page.

---

## Ported

| SteamOS 3.8.4 | On Io | Notes |
|---|---|---|
| `linux-neptune-616` (6.16.12) | `linux-neptune-72` 7.2.4 | Newer branch, see [Kernel](Kernel) |
| `jupiter-hw-support` (20260327.1) | `deck-hw-support` (20260807.1) | Helpers under their `steamos-*` names, see [Helper status](Helper-Status) |
| `steamos-manager` (26.1.0) | `io-steamos-manager` | Io's own implementation, see [Architecture](Architecture) |
| `steam-jupiter-stable` (1.0.0.85-8) | `steam-jupiter` (-12) | |
| `steamdeck-dsp` (0.91) | `steamdeck-dsp` 1.02 | Sink loopbacks kept as in 0.91 |
| `steamdeck-kde-presets` (3.8.5) | 3.9.4 | |
| `jupiter-fan-control` (20260422.2) | 20260902.1 | runit service |
| `vpower` (1.5.7) | 1.6.3 | Patched hwmon path |
| `xdg-desktop-portal-gamescope` (0.1.33) | 0.1.38 | |
| `xdg-desktop-portal-holo` (0.1.18) | 0.1.18 | Started by D-Bus, no systemd unit |
| `steamos-systemreport` (0.16) | 1.23 | socklog and xbps instead of journal and pacman |
| `steamos-powerbuttond` (4.2) | 4.2 | |
| `steamos-networking-tools` (1.2) | 1.2 | runit port of the backend switch |
| `steamos-passwd` (1.0) | 1.0 | |
| `steamos-devkit-service` (0.20250916.0) | same | mDNS through Avahi |
| `steam-im-modules` (20240131) | same | |
| `steam_notif_daemon` (1.0.1) | 1.0.1 | sd-bus from libelogind; started by the game mode session |
| `drm_janitor` (0.0.4) | 0.0.4 | Run by the game mode session when gamescope exits |
| `cecd` (0.2.0), `cec-audio-control` (0.1.0) | same | |
| `gpu-trace` (2.14) | 2.14 | runit service |
| `holo-zram-swap` (0.3) | 0.3 | runit service |
| `holo-earlyoom` (1.1) | 1.1 | |
| `holo-dmi-rules` (1.1) | 1.1 | Core service instead of tmpfiles |
| `holo-fstab-repair` (0.1) | 0.2 | Runs at every boot |
| `holo-sudo` | same files | Checked against Valve's source for 3.8.4 (2026-10-03) |
| `jupiter-firewall` (0.1) | 0.1 | ufw instead of firewalld |
| `steamos-customizations-jupiter` | `steamos-tuning` (parts) | Sysctls, `modules-load.d`, early HID drivers, scheduler tunings, swap file; the A/B parts are not ported (see below). The hibernation guard next to them is Io's own |
| `steamos-tweak-mtu-probing` | in `steamos-tuning` | |
| `lib32-gamescope` (3.16.15) | `gamescope-wsi-32bit` 3.16.30 | Only gamescope's WSI layer for 32-bit Vulkan games (frame limiter, bypass, HDR), built for i686 from gamescope's source |
| `jupiter-legacy-support` | parts | `KillUserProcesses` (in `io-session`) and `steam-web-debug-portforward`; Valve's own header calls the rest leftovers to be removed |

Newer than SteamOS 3.8.4 and ported as well: `holo-upower-config`,
`holo-realtek-firmware-toggles`.

## Replaced by Io's own or Void's

| SteamOS 3.8.4 | On Io |
|---|---|
| `holo-plymouth-themes` | `io-branding` (Valve's logos are Valve's trademarks) |
| `holo-glibc-locales` | Void's `glibc-locales`; the image build generates the same set of locales |
| `gamescope` (3.16.23) | Void's gamescope 3.16.30 |
| `mangohud`, `gamemode`, `orca`, `speech-dispatcher`, `espeak-ng`, `sof-firmware`, `sdl2-compat`, `sdl3` | Void's packages |
| `linux-firmware-neptune`, `amd-ucode-neptune` | Void's `linux-firmware` packages (the amplifier firmware, the Wi-Fi firmware and AMD's microcode are in them). Checked 2026-10-03: nothing the LCD needs is missing, but Valve's own Realtek Bluetooth firmware (most likely needed for wake-on-Bluetooth) is not in Void's, and 8 of the 11 `vangogh_*` files differ, see [Deviations](Deviations) |
| `scx-scheds` | Void's `scx`, switched through a runit service by `io-steamos-manager` |

## Not on Io

| SteamOS 3.8.4 | Why |
|---|---|
| `steamos-atomupd-client`, `atomupd-daemon`, `rauc`, `holo-desync`, `steamos-efi` | Atomic A/B system updates; Io updates with xbps. System updates from Steam are a later milestone |
| `steamos-reset` | Factory reset of the A/B system; an Io reset would be its own design |
| `dmemcg-booster`, `kcgroups`, `plasma-foreground-booster` | Driven by systemd's units and slices (`org.freedesktop.systemd1`); nothing to hook into under runit. The kernel side (`CGROUP_DMEM`) is there |
| `steamos-log-submitter`, `jupiter-steamos-log-submitter` | Sends crash logs to Valve; would have to be retargeted first |
| `kdumpst`, `steamos-kdumpst-layer` | Kernel crash dumps, developer-facing; parked |
| `jupiter-dock-updater-bin` | Needs Valve's dock; the updater is a stub that reports "up to date" |
| `inputplumber` | Installed on SteamOS 3.8.4 but not running on the Deck |
| `galileo-mura` | Steam Deck OLED only |
| `dirlock` | Home directory encryption, filed with the A/B notes below (decided 2026-10-03) |
| `holo-keyring`, `holo-nix-offload`, `holo-nfs-utils-tmpfiles` | pacman keys, Nix store, NFS: nothing Io needs |

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
  `hibernate-swap-helper.sh cleanup`, belongs to the resume path Io will
  need with suspend-then-hibernate. The rest of the
  sleep setup is on [Deviations](Deviations) (*System services*);
  `modules-reload.sh` only concerns the OLED's Wi-Fi (`ath11k`).
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

## Valve's newer versions (checked 2026-10-03)

Against Valve's 3.9, main and staging branches. Valve's main branch (after
3.9) renames most `steamos-*` tools to `holo-*` (`holo-systemreport`,
`holo-networking-tools`, `holo-passwd`, `holo-sudo-config`; `steamos-alias`
links the old names); 3.9 still ships the `steamos-*` names. Steam still
calls the old names, so Io keeps them.

| Package | Io | Valve's newest | Worth it? |
|---|---|---|---|
| `cecd` | 0.2.0 | 0.3.0 | Yes: holds suspend to put the TV in standby (logind delay inhibitor, works with elogind), *Request Active Source*, no double suspend, no reply loop on *Feature Abort* |
| `linux-neptune-72` | 7.2.4 | 7.2.7.valve1 | Yes, not urgent: display interrupt race (`flip_done` timeouts), VRAM after resume, backlight steps, S4 wake bits, Valve's Bluetooth delay removed; decide the configuration with it ([Kernel](Kernel)) |
| `gpu-trace` | 2.14 | 2.16 | Small: the daemon shuts down cleanly |
| `holo-realtek-firmware-toggles` | 1.3-1 | 1.3-3 | Small: low-latency mode turns aggressive EDCA on (rtw89 USB sticks only) |
| `steamos-customizations-jupiter` | 3.8.4's | 20260916.1 | Proton nice limit at the right path; rest A/B and renames |
| `steamos-manager` (API) | 26.1.0 | 26.4.1 | Nothing Steam needs. Optional: `HdmiCec2`, `SwitchToDesktopSession`; `Audio1` was removed |
| `jupiter-hw-support` | 20260807.1 | 20260930.1 | No: controller firmware updater only |
| `steamos-networking-tools` | 1.2 | 1.3 / `holo-networking-tools` 1.4 | No: one error message, then the rename |
| `steamos-systemreport`, `steamos-passwd` | 1.23, 1.0 | `holo-*` | No: renames |
| `steam_notif_daemon`, `xdg-desktop-portal-holo`, `steamos-powerbuttond` | | new pkgrel | No: rebuilds without code changes |
| `rnnoise-ladspa` | 1.10 | upstream 1.21 | No: the LADSPA plugin's default voice threshold rose from about 25 % to about 74 %, and Valve's filter chain sets none; the microphone would cut more |

All other ported packages are at Valve's newest version.

---

## Not evaluated yet (name check 2026-10-03)

Names in Valve's `jupiter-*` and `holo-*` repositories that this page did
not mention. To be evaluated one by one.

**Valve's own, installed on SteamOS 3.8.4:** `fremont-hw-support` (Steam
Machine hardware support, also on the Deck), `inputattach-cec-units`,
`usbhid-gadget-passthru`, `fwupd-minimal`, `breakpad`, `zenity-gtk3`,
`ttf-twemoji-default`, `ibus-pinyin`, `ibus-table-cangjie-lite`,
`renderdoc-minimal` (+ 32-bit), `umr`, `maliit-framework` (Valve's build),
`paru` (irrelevant).

**Valve's own, not installed on 3.8.4** (some are in its repositories): `wireless-domain-setter`, `rtl88x2ce-dkms`,
`steamos-repair-tool-git`, `steamos-repair-backend-git`,
`steamos-media-creation-git`, `calamares` with
`calamares-settings-steamos-git`, `wakehook` and
`plasma-remotecontrollers` (the old CEC path), `steamfs-git`, `foxnet`,
`foxnetstatsd`, `jupiter-validation-tools`, `kdump-steamos`, `libevdi`,
image and packaging tools (`debos`, `bmaptool`, `holo-rust-packaging-tools`,
`libversion`, `ckbcomp`), other kernel series and variants.

**New small `holo-*` packages:** split out of `steamos-customizations`:
`holo-plymouth-config`, `holo-debuginfod-config`, `holo-desync-config`,
`holo-sudo-config` (same files as Io's `holo-sudo`). Also new:
`holo-session-selection`, `holo-libva-config`
(`LIBVA_DRIVER_NAME=radeonsi`), `holo-grant-cap-sys-nice` (`cap_sys_nice`
for SteamVR's compositor, already in the 3.8 repository).
`holo-config-mtu-probing` ships the `20-mtu-probing.conf` Io already has in
`steamos-tuning`.

**Arch packages Valve rebuilds in its own repositories** (patches or just
earlier versions; to check): in `jupiter` `powerdevil`, `bluedevil`,
`kwin-x11`, `drkonqi`, `ibus-anthy`, `pyzy`, `renderdoc`, 32-bit Mesa
variants; in `holo` `networkmanager`, `libinput`, `libei`, `libdrm`,
`libdisplay-info`, `xorg-xwayland`, `xorg-server`, `kscreenlocker`,
`kwindowsystem`, `kcoreaddons`, `plasma-desktop`, `plasma-pa`,
`pulseaudio-qt`, `discover`, `krdp`, `cups`, `dkms`, `podman`,
`bubblewrap`, `xdg-dbus-proxy`, `casync`, `desync`, `lsb-release`,
`libxml2`, `pcre2`, `gnutls`, `libssh2`, `libpng`, `hwdata`, `7zip`,
`linux-lts`.
