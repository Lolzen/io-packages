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
| `holo-sudo` | same files | |
| `jupiter-firewall` (0.1) | 0.1 | ufw instead of firewalld |
| `steamos-customizations-jupiter` | `steamos-tuning` (parts) | Sysctls, `modules-load.d`, early HID drivers, scheduler tunings, swap file; the A/B parts are not ported (see below). The hibernation guard next to them is Io's own |
| `steamos-tweak-mtu-probing` | in `steamos-tuning` | |
| `jupiter-legacy-support` | parts | `KillUserProcesses` (in `io-session`) and `steam-web-debug-portforward`; Valve's own header calls the rest leftovers to be removed |

Newer than SteamOS 3.8.4 and ported as well: `holo-upower-config`,
`holo-realtek-firmware-toggles`.

## Replaced by Io's own or Void's

| SteamOS 3.8.4 | On Io |
|---|---|
| `holo-plymouth-themes` | `io-branding` (Valve's logos are Valve's trademarks) |
| `holo-glibc-locales` | Void's `glibc-locales`; `mkimg.sh` generates the same set of locales |
| `gamescope` (3.16.23) | Void's gamescope 3.16.30 |
| `mangohud`, `gamemode`, `orca`, `speech-dispatcher`, `espeak-ng`, `sof-firmware`, `sdl2-compat`, `sdl3` | Void's packages |
| `linux-firmware-neptune`, `amd-ucode-neptune` | Void's `linux-firmware` packages (the amplifier firmware, the Wi-Fi firmware and AMD's microcode are in them) |
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
| `lib32-gamescope` | Void builds gamescope for 64 bit only, so 32-bit Vulkan games run without gamescope's WSI layer. Worth checking whether a game notices |
| `dirlock` | Encryption of the home directory with fscrypt, experimental and opt-in in SteamOS 3.8 (a PAM module unlocks it at login). Not ported: it would need a look at Io's PAM chain and SDDM's autologin first |
| `holo-keyring`, `holo-nix-offload`, `holo-nfs-utils-tmpfiles` | pacman keys, Nix store, NFS: nothing Io needs |

---

## Guiding principle

Fewer dead stubs is good, but never at the cost of Io's own stability or
security. Most of this is "adapt", not "copy".

---

## Notes on Valve's A/B mechanics

Found while reading `steamos-customizations-jupiter`; nothing of it is
ported, but it explains some of Valve's choices:

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

Not opened yet in the same package: `swap/`, `offload/`, and
`misc/sleep.conf.d` (suspend-then-hibernate).
