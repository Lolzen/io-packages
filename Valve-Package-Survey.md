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
| `linux-neptune-72` 7.2.7 (3.8.4: `linux-neptune-616` 6.16.12) | `linux-neptune-72` 7.2.4 | 7.2.7 planned, see [Kernel](Kernel) |
| `jupiter-hw-support` 20260807.1 (20260327.1) | `deck-hw-support` 20260807.1 | Helpers under their `steamos-*` names, see [Helper status](Helper-Status) |
| `steamos-manager` 26.4.1 (26.1.0) | `io-steamos-manager` | Io's own implementation, see [Architecture](Architecture); 26.4.1's `HdmiCec2` and `SwitchToDesktopSession` still missing |
| `steam-jupiter-stable` 1.0.0.85-12 (-8) | `steam-jupiter` (-12) | |
| `steamdeck-dsp` 1.02 (0.91) | `steamdeck-dsp` 1.02 | Sink loopbacks kept as in 0.91 |
| `steamdeck-kde-presets` 3.9.4 (3.8.5) | 3.9.4 | |
| `jupiter-fan-control` 20260902.1 (20260422.2) | 20260902.1 | runit service |
| `vpower` 1.6.3 (1.5.7) | 1.6.3 | Patched hwmon path |
| `xdg-desktop-portal-gamescope` 0.1.38 (0.1.33) | 0.1.38 | |
| `xdg-desktop-portal-holo` 0.1.18 | 0.1.18 | Started by D-Bus, no systemd unit |
| `steamos-systemreport` 1.23 (0.16) | 1.23 | socklog and xbps instead of journal and pacman |
| `steamos-powerbuttond` 4.2 | 4.2 | |
| `steamos-networking-tools` 1.3 (1.2) | 1.2 | runit port of the backend switch; 1.3 planned |
| `steamos-passwd` 1.0 | 1.0 | |
| `steamos-devkit-service` 0.20250916.0 | same | mDNS through Avahi |
| `steam-im-modules` 20240131 | same | |
| `steam_notif_daemon` 1.0.1 | 1.0.1 | sd-bus from libelogind; started by the game mode session |
| `drm_janitor` 0.0.4 | 0.0.4 | Run by the game mode session when gamescope exits |
| `cecd` 0.3.0 (0.2.0), `cec-audio-control` 0.1.0 | `cecd` 0.2.0, `cec-audio-control` 0.1.0 | cecd 0.3.0 planned |
| `gpu-trace` 2.16 (2.14) | 2.14 | runit service; 2.16 planned |
| `holo-zram-swap` 0.3 | 0.3 | runit service |
| `holo-earlyoom` 1.1 | 1.1 | |
| `holo-dmi-rules` 1.1 | 1.1 | Core service instead of tmpfiles |
| `holo-fstab-repair` 0.2 (0.1) | 0.2 | Runs at every boot |
| `holo-sudo` | same files | Checked against Valve's source for 3.8.4; unchanged since (Valve's main branch moves it to `holo-sudo-config`) |
| `holo-upower-config` 1.0 (not on 3.8.4) | 1.0 | With a fix for Valve's `yes`/`true` bug |
| `holo-realtek-firmware-toggles` 1.3-3 (not on 3.8.4) | 1.3-1 | 1.3-3 changes one line (low-latency mode); planned |
| `jupiter-firewall` 0.1 | 0.1 | ufw instead of firewalld |
| `steamos-customizations-jupiter` 20260827.2 | `steamos-tuning` (parts) | Sysctls, `modules-load.d`, early HID drivers, scheduler tunings, swap file; the A/B parts are not ported (see below). The hibernation guard next to them is Io's own. Not yet taken from 3.9.2: the Proton nice limit (see [Deviations](Deviations)) |
| `steamos-tweak-mtu-probing` | in `steamos-tuning` | |
| `lib32-gamescope` 3.16.30 (3.16.15) | `gamescope-wsi-32bit` 3.16.30 | Only gamescope's WSI layer for 32-bit Vulkan games (frame limiter, bypass, HDR), built for i686 from gamescope's source |
| `jupiter-legacy-support` | parts | `KillUserProcesses` (in `io-session`) and `steam-web-debug-portforward`; Valve's own header calls the rest leftovers to be removed |

## Replaced by Io's own or Void's

| SteamOS 3.9.2 | On Io |
|---|---|
| `holo-plymouth-themes` | `io-branding` (Valve's logos are Valve's trademarks) |
| `holo-glibc-locales` | Void's `glibc-locales`; the image build generates the same set of locales |
| `gamescope` 3.16.30 (3.16.23) | Void's gamescope 3.16.30 |
| `mangohud`, `gamemode`, `orca`, `speech-dispatcher`, `espeak-ng`, `sof-firmware`, `sdl2-compat`, `sdl3`, `knighttime` | Void's packages |
| `linux-firmware-neptune`, `amd-ucode-neptune` | Void's `linux-firmware` packages (the amplifier firmware, the Wi-Fi firmware and AMD's microcode are in them). Nothing the LCD needs is missing, but Valve's own Realtek Bluetooth firmware (most likely needed for wake-on-Bluetooth: SteamOS loads it and logs "wake-on-bluetooth enabled") is not in Void's, and 8 of the 11 `vangogh_*` files differ, see [Deviations](Deviations). An add-on package is planned |
| `mesa`, `vulkan-radeon` (Valve's builds) | Void's Mesa, see [Deviations](Deviations) (*Graphics*) |
| `scx-scheds` | Void's `scx`, switched through a runit service by `io-steamos-manager` |
| `iio-sensor-proxy` (new in 3.9.2) | Not on Io: removed in Alpha 5, when SteamOS 3.8.4 did not have it either; Steam reads the light sensor itself. On 3.9.2 it runs, but nothing in game mode uses it |

## Not on Io

| SteamOS 3.9.2 | Why |
|---|---|
| `steamos-atomupd-client`, `atomupd-daemon`, `rauc`, `holo-desync`, `steamos-efi` | Atomic A/B system updates; Io updates with xbps. System updates from Steam are planned through the `steamos-update` script, see [Helper status](Helper-Status) |
| `steamos-reset` | Factory reset of the A/B system; an Io reset would be its own design |
| `dmemcg-booster`, `kcgroups`, `plasma-foreground-booster` | Driven by systemd's units and slices (`org.freedesktop.systemd1`); decided not to implement, see [Deviations](Deviations) |
| `steamos-log-submitter`, `jupiter-steamos-log-submitter` | Sends crash logs to Valve; would have to be retargeted first |
| `kdumpst`, `steamos-kdumpst-layer` | Kernel crash dumps, developer-facing; parked |
| `jupiter-dock-updater-bin` | Needs Valve's dock; the updater is a stub that reports "up to date" |
| `inputplumber` | Installed but not running on the Deck (3.8.4 and 3.9.2) |
| `galileo-mura` | Steam Deck OLED only |
| `dirlock` | Home directory encryption, filed with the A/B notes below (decided 2026-10-03) |
| `holo-keyring`, `holo-nix-offload`, `holo-nfs-utils-tmpfiles` | pacman keys, Nix store, NFS: nothing Io needs |
| `steamos-alias` (new in 3.9.2) | A pacman hook linking `steamos-*` names to the renamed `holo-*` helpers; Io keeps the `steamos-*` names Steam calls |
| `wireless-domain-setter` (new) | Does nothing on the LCD ("no self-managed phy's"); for the OLED's and Steam Machine's Wi-Fi |
| `ec-log`, `holo-debuginfod-config`, `holo-grant-cap-sys-nice` (new) | Embedded controller logging for other hardware (service disabled); debug symbols only for SteamOS builds; `cap_sys_nice` for SteamVR's compositor |
| `holo-session-selection` (new) | `holo-session-select` and SDDM's `holo.conf`; Steam calls `steamos-session-select`, which Io has |
| `plasma-login-manager`, `plasma-keyboard` (new) | Login manager installed but disabled (SDDM stays); `plasma-keyboard` replaces Maliit on 3.9.2 — planned for Io |

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

## Updates planned for Alpha 6

What SteamOS 3.9.2 runs and Io does not have yet (checked 2026-10-03/04;
Valve's main branch renames most `steamos-*` tools to `holo-*`, 3.9.2 still
ships the old names, and Steam still calls them):

| Package | Io | SteamOS 3.9.2 | Why |
|---|---|---|---|
| `cecd` | 0.2.0 | 0.3.0 | Holds suspend to put the TV in standby (logind delay inhibitor, works with elogind), *Request Active Source*, no double suspend, no reply loop on *Feature Abort* |
| `linux-neptune-72` | 7.2.4 | 7.2.7.valve1 | Display interrupt race (`flip_done` timeouts), VRAM after resume, backlight steps, S4 wake bits, Valve's Bluetooth delay removed; with the configuration base ([Kernel](Kernel)) |
| `gpu-trace` | 2.14 | 2.16 | The daemon shuts down cleanly |
| `holo-realtek-firmware-toggles` | 1.3-1 | 1.3-3 | Low-latency mode turns aggressive EDCA on (rtw89 USB sticks only) |
| `steamos-networking-tools` | 1.2 | 1.3 | An error message when `wlan0` cannot be added |
| `steamos-customizations-jupiter` | 3.8.4's | 20260827.2 | Proton nice limit at the right path; the rest is A/B work and renames |
| `steamos-manager` (API) | 26.1.0's | 26.4.1 | `HdmiCec2` (the current Steam beta uses it), `SwitchToDesktopSession`; `Audio1` removed |

Not taken: `rnnoise-ladspa` stays 1.10 (upstream 1.21 raised the LADSPA
plugin's default voice threshold from about 25 % to about 74 %, and Valve's
filter chain sets none; the microphone would cut more).

---

## Evaluated 2026-10-04 (name check of Valve's repositories)

Names in Valve's `jupiter-*` and `holo-*` repositories this page did not
mention before, checked against SteamOS 3.9.2 and Void.

**To do (in the Alpha 6 plan):** input methods for Steam's keyboard
(`ibus-daemon` in game mode as SteamOS's `ibus-gamescope.service`; the
engines `ibus-pinyin` with `pyzy`, `ibus-table` with `cangjie-lite`,
Valve's `ibus-anthy` fork, Void's `ibus-hangul`), `holo-libva-config`
(`LIBVA_DRIVER_NAME=radeonsi`), a colour emoji font (`ttf-twemoji-default`
or Void's `noto-fonts-emoji`), `plasma-keyboard` instead of Maliit.

**Skipped:** `fremont-hw-support` (Steam Machine BIOS only),
`usbhid-gadget-passthru` (USB device mode, developer tool),
`fwupd-minimal` (Deck BIOS goes through `jupiter-biosupdate`; Void has
`fwupd`), `breakpad` and `umr` (log submitter only), `renderdoc-minimal`
(developer tool), `rtl88x2ce-dkms` (the LCD uses the kernel's `rtw88`),
other kernel series, and the old CEC path (`wakehook`,
`plasma-remotecontrollers`).

**To check:** `zenity-gtk3` (Void's `zenity` should do, Steam only uses
`zenity --error`; test that its dialogs work), `inputattach-cec-units`
(optional, only for USB CEC adapters).

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

**Arch packages Valve rebuilds with patches:** nothing Io must carry today.
Worth having, without rebuilding Void's packages where possible: Valve's
Bluetooth settings (`MultiProfile=multiple`, `FastConnectable=true`,
`ScanIntervalSuspend=2240`, `ScanWindowSuspend=224`), the desktop keeping
the brightness set in game mode (kwin patch, KDE bug 508163), mangoapp
drawing once per game frame (MangoHud, fixed upstream after 0.8.4).
Watched: NetworkManager (Valve scans only the last channel after resume;
Void is on 1.56), PipeWire's next major release (Bluetooth profiles, dock
HDMI fixes), Steam's keyboard in the desktop (kwin and Xwayland patches),
and Void's `wpa_supplicant`, built without the roaming features
(WNM, MBO) Arch enables.
