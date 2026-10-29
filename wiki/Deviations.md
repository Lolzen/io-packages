# Deviations from SteamOS

Reference: SteamOS 3.9.2 (Beta Candidate, build 20260925.101, kernel 7.2.7,
Steam client beta) on the same Steam Deck LCD, captured on 2026-10-04
(process environments and capabilities, SteamOS Manager D-Bus values and
calls per step, sysfs, systemd units, configuration files, firmware); until
then SteamOS 3.8.4, captured in September 2026. The Deck's SSD is a
retrofitted 1 TB KIOXIA, not the one it shipped with. Everything not listed
here is meant to behave as on SteamOS; a difference that is not on this page
is a bug.

---

## Versions

Where Valve's newer source differs from what the reference SteamOS runs, Io
takes the newer state if it makes sense; Io's ported packages chosen this
way under 3.8.4 turned out to be what 3.9.2 runs (apart from the updates
listed under *Other ported packages*). Io stays with the
older state when the change is transitional or Arch- or systemd-specific,
or when the older one simply fits Io better. Each such choice is written down on this page with
its reason.

---

## Design choices

| Io | SteamOS | Why |
|---|---|---|
| Void Linux with runit | Arch Linux with systemd | The point of the project |
| Writable root file system, software through xbps | Read-only root, A/B images, atomic updates | Simpler, and lets users install anything from Void's repositories. A/B updates are a possible post-1.0 goal |
| No Flatpak, no Discover; OctoXBPS as graphical package manager | Flatpak through Discover | SteamOS needs Flatpak because its root is read-only. Io does not; Flatpak can still be installed by hand |
| Built and tested on the Steam Deck LCD (Jupiter); the OLED (Galileo) and the Steam Machine get Valve's packages and settings for them, untested, with gaps (see [Milestones](Milestones)) | LCD, OLED (Galileo) and the Steam Machine | No hardware other than the LCD to test with |
| Disk image written with `dd` to an SD card, or a recovery stick that installs Io on a disk of the Deck ([Installation](Installation)) | Recovery image with installer | Fixed hardware, nothing for an installer to ask. The recovery stick is a plain writable Void system instead of a live ISO: self-built live ISOs stop in dracut's emergency shell (cause not found) |
| Io-branded boot splash and update screen | SteamOS logo | Valve's logos are Valve's trademarks; Io does not ship them |
| Io's own messages are English only, not localized | Localized | One-person project; English as the common denominator |
| GRUB boots Io without its menu; *Restart* from Io starts Io again (UEFI `BootNext`), switching on starts the firmware's default system | `steamcl` without a menu, SteamOS on the internal SSD is the firmware's default | Io on an SD card has no boot entry of its own (GRUB at the removable path), so a restart started the internal SteamOS. `BootNext` lasts one boot, so SteamOS stays the default. Io installed on the internal SSD with the recovery stick has its own entry and is the default itself. A boot that goes wrong ends in dracut's emergency shell; the recovery stick keeps its menu |
| SSH server enabled out of the box, user `deck` with password `deck` | SSH off; enabled through Steam's developer settings, no password until the user sets one | Needed during the alpha and beta phases. Images for 1.0 will follow SteamOS |

---

## Login and sessions

- **SDDM as on SteamOS**, with the same autologin and `Relogin`, run as
  the runit service `io-sddm`. Its settings are Io's own, under Valve's file
  name (`/usr/lib/sddm/sddm.conf.d/holo.conf`, which steamos-manager looks
  for), with the Wayland greeter on kwin. Each session runs `io-start`
  under its own `dbus-run-session`;
  SteamOS uses systemd user units instead. Valve's SDDM file also sets
  `InputMethod=qtvirtualkeyboard`; Io leaves it out, since it is SDDM's
  default and SDDM 0.21 drops it for a Wayland greeter anyway.
- **The desktop session is `io-desktop.desktop`**, not Plasma's own
  `plasma.desktop`: it runs Io's session setup (PipeWire, the filter chain,
  Steam's DPI setting) before Plasma, which SteamOS does through user
  services. `steamos-session-select` (Valve's `holo-session-select`) names
  it in place of Plasma's sessions, and `io-manager-session` makes it the
  default desktop session while Valve's default (`plasma.desktop`) is set.
  Plasma's own session files stay installed; chosen by hand, they start
  Plasma without Io's session setup. Io has no X11 desktop session.
- **gamescope starts Steam as its child.** SteamOS runs gamescope and Steam
  as two systemd units and passes the display names through a startup socket
  (`-R`); Io does not need it. The statistics pipe (`-T`) is set as on
  SteamOS.
- **Steam launch flags, gamescope arguments and environment match
  SteamOS 3.9.2**, except `STEAM_LAUNCH_WRAPPER_SCOPE` (it has Steam start
  each game in a systemd scope, and Io has no systemd).
  `LIBVA_DRIVER_NAME=radeonsi` comes from Valve's `/etc/profile.d/libva.sh`
  (`steamos-customizations-jupiter`), for every login as on SteamOS.
- **`ibus-daemon` for Steam's keyboard** is started by `io-gamemode` once
  gamescope is up, with the same arguments as SteamOS's
  `ibus-gamescope.service` (a user service there).
- **HDMI-CEC:** `cecd` starts through D-Bus activation, after
  `steamosctl configure-cecd` (`io-manager-session`), and
  `cec-audio-control` directly from the session scripts (SteamOS: user
  services of the graphical session, `cec-audio-control` socket-activated).
  Access to `/dev/cec*` and `/dev/uinput` comes from group rules (`video`,
  `input`) instead of systemd's `uaccess`.
- **Logging out ends every process of the session**, as on SteamOS
  (`KillUserProcesses`), set in elogind.
- **Steam's notification daemon and `drm_janitor`** are started by
  `io-gamemode`: the daemon with the session, `drm_janitor` when gamescope
  exits. SteamOS runs the first as a user service of the game mode session
  and the second from a drop-in for `gamescope-session.service`
  (`ExecStopPost`).
- **mangoapp and gamemode** are started differently: mangoapp by the session
  script in a loop tied to gamescope (Valve: a user service with
  `Restart=always`), gamemode on demand through D-Bus (Valve: a service that
  always runs).
- **Galileo's mura correction** (`galileo-mura-setup`) is started by
  `io-gamemode` on the OLED once gamescope has set its
  `GAMESCOPE_XWAYLAND_SERVER_ID` root property, the sign that it listens
  for the correction's X property. SteamOS starts it as a user service after
  `gamescope-session.service` is ready.
- **The text console stays on tty1** with a login prompt. SteamOS moves it
  to tty4–6 (`fbcon=vc:4-6`). The sessions run on tty7 either way.
- **On-screen keyboard in the desktop:** `plasma-keyboard`, as SteamOS 3.9.2
  (it replaced Maliit there). As on SteamOS it is not set as kwin's input
  method by default; System Settings → Keyboard → Virtual Keyboard turns it
  on. The recovery stick's build sets it (it opens on touch only).
- **Screen sharing in the desktop:** Steam asks Plasma's portal for the
  screen when it starts in the desktop. As on SteamOS, it gets all screens
  without Plasma's *Share screen with* dialog when it has no saved choice
  (Valve's patch to `xdg-desktop-portal-kde`, in `xdg-desktop-portal-kde-holo`);
  a choice made earlier is restored. SteamOS's portal knows Steam by its
  systemd unit (`app-steam@…`); without systemd every host application has
  an empty app id, so Io recognises Steam by the client binary behind the
  request (`steamrt64/steam` or `ubuntu12_32/steam`). Tested 2026-10-29: no
  dialog, the saved choice is the Deck's screen.
- **Touch only with the dock:** SteamOS switches the trackpads and the
  pointer off while the dock is attached and leaves only the touchscreen
  (seen with a mirrored display); Io leaves them on. Not looked into yet.
- **Session output goes to a rotating log** (`/run/user/1000/io-log-<session>/`,
  or `~/.local/state/io/` while Steam's developer mode is on) instead of
  the systemd journal.

---

## SteamOS Manager

Valve's `steamos-manager`, built from the branch `runit` of
[Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager):
Valve's main branch of 2026-10-24 (`a3b2013`, newer than SteamOS 3.9.2's
26.4.1) with seven commits that let it run without systemd, written to be
offered to Valve. How it does without systemd is on
[Architecture](Architecture), *SteamOS Manager*. Until October 2026 Io ran
its own implementation (`io-steamos-manager`).

- **Access to the root half** is limited to root and the `wheel` group
  (Io's D-Bus policy). Valve allows any local user.
- **Started without user units:** the root half is a runit service, the
  session half starts through D-Bus activation on the session's bus. What
  Valve's user units do at session start (`steamos-manager-session-cleanup`,
  `steamos-manager-configure-cecd` before `cecd`) is done by
  `io-manager-session`.
- **Login mode, logout, Orca and system services** go through the
  session's `XDG_CURRENT_DESKTOP`, logind, a child process and runit
  instead of systemd units; see [Architecture](Architecture).
- **Calls from games** are recognised by Steam's `reaper SteamLaunch`
  among the caller's parent processes, not by the `app-steam-app…`
  systemd scope (Io has no per-game cgroups; `STEAM_LAUNCH_WRAPPER_SCOPE`
  stays unset, see *Login and sessions*).
- **Default desktop session** `io-desktop.desktop` (Valve:
  `plasma.desktop`), see *Login and sessions*.
- **`CpuScheduler1`:** the LAVD scheduler is the runit service `scx`,
  linked with a `down` file and Valve's `/etc/default/scx`; a choice lasts
  until the next boot, as on SteamOS, where `scx.service` is not enabled.
- **`FactoryReset1`** and Steam's factory reset call `steamos-reset-tool`
  as Valve's `platform.toml` says; on Io that is `io-factory-reset`'s (see
  *Factory reset*).
- **`com.steampowered.Atomupd1`** comes from Io's `io-atomupd`, not from
  SteamOS Manager or atomupd-daemon; see *System updates*.
- **Wi-Fi backend:** wpa_supplicant by default, as Valve ships SteamOS
  3.9.2 (3.8.4 still defaulted to iwd; the captured Deck runs iwd because
  it was switched in Steam's settings). Switching works in both
  directions; iwd runs as a runit service linked only while it is the
  backend. Wi-Fi debug mode (OLED only, as on SteamOS) sets iwd's `-d`
  through `OPTS` in `/etc/sv/iwd/conf` instead of a systemd drop-in, and
  leaves a `conf` file it did not write alone.
- **`STEAM_USE_WPASUPPLICANT=1` in the desktop as well:** SteamOS's
  gamescope-session sets it for game mode only. Steam sets the Wi-Fi
  backend itself when it starts: with the variable it keeps the backend
  set in Steam (on Io wpa_supplicant; the SteamOS Deck captured on 3.9.2
  ran iwd in game mode, switched in Steam's settings), without it it
  switches to iwd. Started without it in Io's
  desktop, Steam switched to iwd and game mode back to wpa_supplicant, at
  every change of mode, with a short Wi-Fi drop each time; iwd did not
  know the networks saved under wpa_supplicant, so Plasma asked for the
  password (measured 2026-10-21; SteamOS's NetworkManager carries Valve's
  patches that mirror wpa_supplicant's connections into iwd, which Io
  leaves out). Io's desktop session (`io-plasma`) sets the variable too.
- **Connectivity check** against GNOME's endpoint (`io-base`); SteamOS uses
  Arch's.
- **Hardware other than the Steam Deck:** Valve's device files come with
  the daemon unchanged. Io is built for the Steam Deck; on the OLED and the
  Steam Machine Valve's packages for them are in place (untested), on other
  handhelds nothing is tested, and InputPlumber, which steamos-manager uses
  for their controllers, is not part of Io.

---

## System services

- **elogind** instead of systemd-logind; **polkit** is started through
  D-Bus only, not as a runit service.
- **Syslog through `socklog-void`** instead of journald. Service logs are
  under `/var/log/socklog/`, kernel messages in `kernel/`.
- **zram swap** is set up by Io's own runit service (`holo-zram-swap`)
  instead of systemd's `zram-generator`, with Valve's values: half of RAM,
  zstd, priority 100, zswap off. Valve's 1 GiB swap file is switched on by
  a core service instead of `swapfile.service` and `home-swapfile.swap`.
- **`wireless-domain-setter`** (Valve's, copies a self-managed Wi-Fi card's
  regulatory domain to the kernel) runs once at boot as a runit service
  that then idles, on every model as on SteamOS (there a systemd service).
  On the LCD it ends at once, as its card is not self-managed; with Valve's
  USB streaming dongle plugged in it also reloads that dongle's driver
  (`rtw89_8852cu`), as on SteamOS.
- **`ec-log`** (Valve's, the Steam Machine's EC console log) is a runit
  service linked with a `down` file, which steamos-manager starts and stops
  for Steam's EC logging (`FirmwareDebug1`), as the systemd unit is
  installed but not enabled on SteamOS. Its log goes through `logger` to
  socklog. Where the EC's log does not exist (every Steam Deck), the service
  takes itself down instead of restarting (Valve: `ConditionPathExists`);
  it mounts debugfs itself if needed (Valve: `sys-kernel-debug.mount`).
- **No hibernation on the Steam Deck**, as Valve decided on its main branch
  (`jupiter-hibernate-disable` 0.1, October 2026): on Valve's Jupiter and
  Galileo elogind is told that hibernation, suspend-then-hibernate and
  hybrid sleep are not allowed. Valve's package is a oneshot unit before
  logind; Io's is a core service before elogind, which reads the DMI
  strings from `/sys/class/dmi/id` instead of asking `dmidecode`. Steam's
  *Standby* is a plain suspend either way. Io's hibernation support stays
  installed for other hardware, and is described below as it worked on the
  Deck until then.
- **Hibernation is allowed only with `/` on the internal NVMe** (Io's own
  core service writes elogind's `sleep.conf.d`); on an SD card or USB drive
  writing about 17 GB takes minutes and wears the medium. On the NVMe,
  Valve's settings of SteamOS 3.9.2 apply: hibernation allowed, and
  suspend-then-hibernate with a delay of 20 minutes for programs that ask
  for it (Plasma's power settings). Steam's *Standby* asks for a plain
  suspend on SteamOS and on Io alike (Valve: hibernation "not yet exposed
  in Game Mode UI"). Differences:
  - **On AC power as well:** elogind 252 has no `HibernateOnACPower=no`, so
    a suspend-then-hibernate also hibernates after 20 minutes when plugged
    in.
  - **Resume path:** SteamOS's systemd writes the image location to an EFI
    variable (`HibernateLocation`) that its initramfs reads. Io's sleep hook
    (`io-hibernate`) writes an EFI variable of its own
    (`IoHibernateLocation`), read and deleted by the dracut module
    `io-resume`; a SteamOS on the same Deck never sees it. Before
    hibernating, the hook also sets BootNext to Io (`io-bootnext`).
  - **Swap file timing:** Valve creates the swap file for the image before
    systemd picks one; elogind picks first (Io's 1 GiB swap file), so the
    hook points the kernel at the new file afterwards.
  - Valve's skip of logind's swap size check
    (`SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK`) is set in elogind's runit
    service (`elogind-holo`).
  - Valve's reset of the A/B boot counter after resuming does not apply.
  **Tested** on the Deck with Io on the NVMe (2026-10-19): hibernating and
  resuming (`loginctl hibernate`).
- **Proton's nice limit** as on SteamOS 3.9.2: `* hard nice -8` in
  `/etc/security/limits.d/15-proton-nice.conf`, read by `pam_limits` in
  SDDM's login (Steam's hard limit 28; game threads run at nice −1, −2 and
  −8). `deck` is not in the `gamemode` group, as on SteamOS: its limit
  would raise Steam's nice range to 30.
- **Open-file limit** 1024 soft / 524288 hard from
  `/etc/security/limits.d/50-io-nofile.conf`; SteamOS gets the same from
  systemd (`DefaultLimitNOFILE`).
- **Firmware comes from Void's `linux-firmware` packages**, not Valve's
  `linux-firmware-neptune`, plus Io's `deck-firmware` with the files where
  Valve's differ and matter: Valve's older `amdgpu/vangogh_vcn.bin` (Void's
  newer one was withdrawn by AMD in September 2026: video decoding with
  older Mesa, e.g. in Flatpaks) and Valve's Realtek Bluetooth firmware
  (`rtl_bt/rtl8822cu_fw.bin`, `rtl8822cu_config.bin`, version
  `0x3d7679d7`). They lie in `/usr/lib/firmware/updates`, which the kernel
  searches first, so Void's files stay untouched. Wake-on-Bluetooth is
  enabled with either firmware. The other `amdgpu/vangogh_*` files that
  differ (mostly newer in Void) are Void's.
- **Bluetooth settings** as SteamOS's (`MultiProfile=multiple`,
  `FastConnectable=true`, scan interval and window during suspend), in a
  file of Io's own (`/usr/share/io/bluetooth/main.conf`) that the
  `bluetoothd` service reads (`-f`); Valve patches them into bluez's
  `main.conf`.
- **sysctls Void's `base-files` set and SteamOS does not** stay as Void's:
  `kernel.kptr_restrict=1`, `kernel.kexec_load_disabled=1`,
  `kernel.unprivileged_bpf_disabled=1` (SteamOS: 0, 0, 2). Hardening; the
  last two cannot be undone at runtime once set.
- **ufw's own `sysctl.conf` is not applied** (`IPT_SYSCTL` emptied by
  `jupiter-firewall`): ufw would set `rp_filter` and `accept_redirects`
  after the boot sysctls, against SteamOS's values.
- **`CAP_SYS_NICE` for kwin** (realtime threads for its main, output and
  input threads), set as a file capability at boot like gamescope's; Arch's
  kwin package carries it.
- **Time sync through chrony**: Void has no `systemd-timesyncd`.
- **Hostname `io`** (SteamOS: `steamdeck`), set by the image build (`build/`).
- **earlyoom** runs with Valve's full argument set; its `--avoid` list names
  runit's processes instead of systemd.
- **`tmpfiles.d` rules** from Valve's packages are boot-time core services
  (`holo-dmi-rules`, `holo-fstab-repair`), since Void has no tmpfiles.
- **`CAP_SYS_NICE` for gamescope** is set as a file capability, exactly as
  on SteamOS, but by a boot-time core service (with kwin's), because
  gamescope comes from Void's package and an update would drop it.
- **Boot splash** is ended by `io-sddm` right before SDDM starts. The
  controller firmware update splash (Valve's `plymouth-wrap`) uses Io's
  theme, which draws the title and progress as Valve's holo theme does
  (`io-branding`; the initramfs is rebuilt when the theme changes).
- **Firmware updates at boot** run from a core service
  (`97-io-firmware-update.sh`) instead of `jupiter-biosupdate.service` and
  `jupiter-controller-update.service`, with the same time limits. Io's
  controller updater does not flash a controller whose firmware is newer
  than Io's copy (SteamOS on the same Deck may have brought a newer one);
  Valve's flashes whatever differs. `steamos-firmware-update` has no fwupd
  branch (Legion Go, Steam Machine): fwupd is not part of Io.
- **Initramfs:** dracut loads the SD card modules before `amdgpu` on
  purpose, so card detection overlaps `amdgpu`'s load (about 3.7 s on its
  own).

---

## Kernel

- **`linux-neptune-72`, 7.2.7**, as SteamOS 3.9.2, built from Valve's
  `linux-integration` tree. The configuration is Void's as the base, the
  full configuration Valve's package builds from and `config-neptune` on
  top, then a few Io overrides, each with its reason — see
  [Kernel](Kernel). Io builds without Rust (Valve: Rust Binder, panic QR
  code); the C Binder takes the Rust one's place.
- **Kernel command line** matches SteamOS except `fbcon=rotate:1` instead of
  `fbcon=vc:4-6` (see *Login and sessions*), no `console=tty1`, and none of
  the systemd- and A/B-specific options (`rd.systemd.gpt_auto`, `fsck.*`,
  `steamos.efi`). Io adds `net.ifnames=0`: SteamOS's Wi-Fi interface is
  `wlan0` as well, while Void's udev would rename it (see *Pitfalls*).
- **No reboot on kernel panic.** SteamOS's panic sysctls are left out:
  Valve pairs them with a crash log submitter, and without one a frozen
  device is more useful for debugging.

---

## Graphics

- **Mesa is Void's 26.2.5 with Valve's patches** (`mesa-holo`, 64 and 32
  bit, see *Io overlay*), not Valve's builds (SteamOS 3.9.2: radeonsi
  26.1.2 with one Valve patch, RADV from Valve's `steamos-26.05` branch, a
  Mesa main snapshot of May 2026). Void's release is newer than both;
  Valve's own commits and the RADV fixes 26.2.5 lacks are carried on top.
  Valve's older fix for *No Rest for the Wicked* (NGG culling off) is not
  in `steamos-26.05` either.
- **gamescope's WSI layer for 32-bit games** is Io's `gamescope-wsi-32bit`,
  built from gamescope's source (SteamOS: `lib32-gamescope`). Void builds
  gamescope for 64 bit only.

---

## Audio (`steamdeck-dsp`)

- **Noise suppression plugin:** Valve uses NoiseTorch's RNNoise LADSPA
  plugin (label `nt-filter`). Io builds werman/noise-suppression-for-voice as
  `rnnoise-ladspa` (label `noise_suppressor_mono`), because Void's NoiseTorch
  package ships no system-wide plugin.
- **Version:** `steamdeck-dsp` 1.03 from Valve's main branch: it lets the
  headphone output stay awake for 15 minutes of silence, against clicks
  (Valve's rule for Galileo's card in a file of Io's own,
  `93-io-galileo-headphones.conf`). SteamOS 3.9.2 runs 1.02; 3.8.4 ran
  0.91, which kept the microphone filter from suspending; 1.02 drops that,
  and Io follows.
- **UCM profile:** Valve's profile from `steamdeck-dsp` (`Internal Mic`,
  headphone sink), as on SteamOS. Void's `alsa-ucm-conf` also ships
  `conf.d/acp5x/Valve-Jupiter-1.conf`, which UCM would pick first by the
  card's long name; `steamdeck-dsp` keeps it out (`noextract`).
- **No hardware profile switching at boot.** SteamOS picks the audio profile
  for the model at boot through symlinks in `/run`. Io installs Jupiter's
  configuration directly into the standard search paths. Valve's Galileo
  profile differs from it in two places, which Io adds: the filter chain's
  target card (`sof-nau8821-max`), as its own configuration
  `filter-chain-galileo.conf` that the session starts instead on the OLED,
  and Valve's speaker filter graph (`92-io-galileo-speakers.conf`, upstream
  WirePlumber's `node.filter-graph.rules`; it matches only the OLED's
  speaker).
- **The Steam Machine** (untested) gets Valve's WirePlumber profile for it
  (HDMI/DisplayPort, the AC3 profile set for ARC, full volume on HDMI),
  installed under `/usr/share/io/wireplumber-fremont`. The session points
  WirePlumber at it with `WIREPLUMBER_CONFIG_DIR` there, which replaces the
  Deck's fragments in `/etc/wireplumber`; Io's sink loopback rule is
  shadowed (Valve's profile loops back sources only), and no filter chain
  runs, as in Valve's profile. Its CEC volume control needs Valve's
  PipeWire and WirePlumber patches, which Void's builds lack; volume stays
  on the machine. AC3 needs the ALSA a52 plugin (`alsa-plugins-ffmpeg`,
  installed with `steamdeck-dsp`).
- **ALSA loopbacks** are created by an Io WirePlumber script that rebuilds
  Valve's `CreateLoopback()`, which only exists in Valve's patched
  WirePlumber. The result matches SteamOS, including the card identity the
  loopback carries — that is what makes Steam show its own localized device
  names.
- **Sources and sinks get a loopback**, as on SteamOS 3.8.4
  (`steamdeck-dsp` 0.91); 1.02 (SteamOS 3.9.2) marks only sources, Io adds
  the sink rule back (`91-io-sink-loopback.conf`). The sink
  loopback keeps applications from seeing the speaker rebuilt: with Steam's
  *Mono audio*, a stream on the bare speaker saw the channel count change,
  and Steam's interface sound closed for good when switching back.
- **Galileo's SOF firmware** (`amd/sof`, `amd/sof-tplg`) is installed as on
  SteamOS; the kernel loads it only on the OLED, whose audio DSP runs SOF.
  Both UCM profiles (`acp5x`, `sof-nau8821-max`) are Valve's.

---

## Other ported packages

- **`steam-jupiter`** replaces Void's `steam` as Valve's package replaces
  Arch's. Its dependency list is Void's plus Valve's additions, in Void's
  names; the standard Steam udev rules keep coming from Void's
  `steam-udev-rules`. Arch's `lib32-pipewire` becomes `pipewire-32bit` plus
  every `libspa-*-32bit`, which Void ships separately.
- **gamescope** is Void's, 3.17.0, built from Valve's source, the version
  Valve's main branch has (SteamOS 3.9.2: 3.16.30); Io's 32-bit WSI layer
  (`gamescope-wsi-32bit`) is built from the same version.
- **`jupiter-firewall`:** Valve's rules with ufw instead of firewalld, which
  Void does not have: SSH, DHCPv6 and every port from 1024 up come in, the
  privileged ports below are rejected. The package sets them up once in ufw,
  so changes made on Plasma's firewall page (`plasma-firewall`, which drives
  ufw here and firewalld on SteamOS) stay. A runit service loads them at
  boot.
- **`steamos-devkit-service`** publishes the Deck on mDNS through Avahi
  instead of systemd-resolved (patch). Avahi runs only while Steam's
  developer mode keeps the devkit service on.
- **`steam-web-debug-portforward`** is a runit service with `socat` instead
  of a socket unit with `systemd-socket-proxyd`.
- **`cecd`** 0.3.0 and **`cec-audio-control`** 0.1.0, built from Valve's
  source archives. `cecd`'s TV standby on suspend uses logind's delay
  inhibitor, which elogind provides as well.
- **`vpower`** is patched to find the `steamdeck-hwmon` directory instead of
  assuming `hwmon3`; **`holo-upower-config`** has `yes` changed to `true`
  so that UPower actually honours it.
- **`deck-hw-support`** is Valve's `jupiter-hw-support` 20260807.1 with the
  helpers under their `steamos-*` names: that version renames them to
  `holo-*` (Valve's `steamos-alias` links them back), the version SteamOS
  3.9.2 runs; Steam still calls the `steamos-*` names. The cursor images come from
  20260327.1, later versions moved them to another package. Several helpers
  are stubs, see [Helper status](Helper-Status). Automount and trimming:
  see *Storage*. `99-sdcard-rescan.rules` (Valve's workaround for
  misdetected SanDisk cards) starts its script through `io-detach` instead
  of `systemd-run`, and is left out while Io runs from an SD card itself:
  rebinding the card reader would take the running system's disk away.
  `steamos-select-branch` knows one branch, `rel` (stable); switching to
  another is refused.
- **`steamos-priv-write`** gives the written files to the `wheel` group
  instead of `deck`, so that it keeps working with another user name
  (`USERNAME` of the image build) or when a user sets up an account of their
  own, and logs through `logger`.
- **`xdg-desktop-portal-gamescope`** no longer aborts when there is no
  journald to log to.
- **`xdg-desktop-portal-holo`** comes without its systemd user unit; its
  D-Bus service file loses the `SystemdService=` line, so the bus starts
  the backend itself.
- **`steam_notif_daemon`** takes its D-Bus library (sd-bus) from libelogind
  instead of libsystemd; the upstream build offers both.
- **`steamdeck-kde-presets`**: the Deck variant of the Vapor theme is written
  into `kdeglobals` directly (Valve picks it with a systemd service);
  *Return to Gaming Mode* is Valve's command, run by `bash` (Void's `sh` is
  dash) with Qt 6's `qdbus` from `/usr/lib/qt6/bin`; IBus uses Void's panel
  path under `/usr/libexec`. Left out:
  the X11-only IBus environment, the nested desktop, Valve's menu overrides
  in `/usr/local` and its Firefox desktop file.
- **Steam's DPI scaling in the desktop** is switched off once per user by
  `io-plasma` (`DPIScaling` 0). Plasma keeps its own 135 %. SteamOS
  (3.8.28, fresh user) shows Steam's keyboard oversized in the desktop; Io
  does not.
- **`steam-im-modules`**: the Qt part is Qt 5 only, as upstream.
- **`jupiter-fan-control`** runs as a runit service; its `finish` script does
  what Valve's `ExecStopPost` does (hand the fan back to the embedded
  controller).
- **`steamos-tuning`** adds what SteamOS inherits from systemd and Arch
  instead of setting it itself: `kernel.pid_max`, `kernel.sysrq`, the
  inotify limits, `fs.protected_regular`/`fifos`, `net.core.default_qdisc`,
  `rp_filter`, `promote_secondaries`, `accept_source_route=0` and
  `ping_group_range` (values as captured on SteamOS, from systemd's
  `50-default.conf`), and `net.unix.max_dgram_qlen=512`, which systemd
  raises at start. Valve's suspend-then-hibernate settings are taken over
  without `HibernateOnACPower` (see *System services*, hibernation).
- **`holo-fstab-repair`** runs Valve's script on every boot; SteamOS runs it
  only when the user changed `fstab` in its `/etc` overlay, which Io does
  not have.
- **Versions:** the ported Valve packages are the versions of SteamOS
  3.9.2 ([SteamOS packages](Valve-Package-Survey)), some of them newer
  (from 3.9.3 or Valve's main branch, see [Milestones](Milestones),
  *Catching up with Valve*). The kernel is Valve's 3.9.3 kernel
  (`7.2.7-valve2`) with stable 7.2.11 merged in ([Kernel](Kernel)).
- **`steamos-systemreport`** reads socklog and Io's session logs instead of
  the journal, and checks packages with xbps instead of pacman.
- **`timedatectl`** is a small replacement script; Steam only uses
  `set-timezone`.
- **ALSA's default device** is routed through PipeWire by links `io-base`
  ships. Void leaves enabling `alsa-pipewire` to the admin; SteamOS has it
  out of the box.

---

## Input methods for Steam's keyboard

- **Chinese, Japanese and Korean** layouts of Steam's keyboard in game mode
  work as on SteamOS: the IBus engines Steam asks for by name (`pinyin`,
  `bopomofo`, `table:cangjie5`, `table:quick5`, `anthy`, `hangul`) come from
  the same sources as SteamOS's: `pyzy` and `ibus-pinyin`, `ibus-table`
  with Valve's `ibus-table-cangjie-lite`, Valve's fork of `ibus-anthy`
  (as `ibus-anthy-holo`, see *Io overlay*) and Void's `ibus-hangul`.
  Differences: `ibus-anthy-holo` is built against Void's `anthy-unicode`
  (Valve: the older `anthy`); `ibus-pinyin` and `pyzy` are built with
  `autoreconf` instead of GNOME's `autogen.sh`.
- **Umlauts from Steam's keyboard:** it types them on Io, in game mode and
  (since Alpha 7) in the desktop, but on SteamOS 3.9.2 in neither (system
  language English, German keyboard; tested with Steam's beta client of
  2026-10-04); why was not looked into.

---

## Io overlay

Where Io needs a patch Valve carries in a package Void also has, it builds
Void's package with the patch as a package of its own, `<name>-holo`, that
replaces Void's (the build is described in io-packages'
[overlay/README.md](https://github.com/Lolzen/io-packages/blob/main/overlay/README.md)).
Void's `-32bit` packages of these stay Void's, except Mesa's: `mesa-holo`
is built for 32 bit as well (`-holo-32bit` packages).

| Package | Replaces | Valve's patches carried |
|---|---|---|
| `MangoHud-holo` | `MangoHud`, `MangoHud-mangoapp` | mangoapp draws once per game frame (MangoHud `2c1dc52`, after 0.8.4; Void's 0.8.4 draws continuously) |
| `NetworkManager-holo` | `NetworkManager`, `libnm`, `NetworkManager-devel` | after resume, scan only the last-associated frequency (MR 2514, not merged). Built with `polkit_noauth_group=wheel` as Valve's 1.58: 1.58 dropped the `modify_system` option Void used, so saving a network for all users would ask for an admin password (no polkit agent in game mode); the rule allows it for local users in `wheel` |
| `bluez-holo` | `bluez`, `libbluetooth` and the other bluez packages | a re-paired device's old entry with the same key is removed (Steam Controller and suspend); the Switch Pro Controller's link may use sniff mode. Built with `-std=gnu17`: Void's autoconf 2.73 makes bluez 5.86 compile as C23, where it fails |
| `ibus-anthy-holo` | `ibus-anthy` | Valve's fork of 1.5.14 (Void: 1.5.16, Valve's changes do not apply to it); not generated from Void's template |
| `kwin-holo` | `kwin`, `kwin-devel` | the desktop takes the panel's current brightness instead of the saved one (KDE bug 508163); text from Steam's keyboard over libei goes past an input method that grabs the keyboard; libei 1.6 keysym and text events (kwin 6.8); no modes below 480p (kwin 6.8); before suspend kwin turns the screens off itself, holds its sleep delay while screens are on and drops it without outputs (Valve's 6.7.3-1.7: frozen picture and looping sound at hibernation on the Steam Machine; kwin master, 6.8) |
| `xorg-server-xwayland-holo` | `xorg-server-xwayland` | text typed through XTEST (Steam's keyboard in the desktop) goes to the compositor as keysyms over libei, so letters outside the first layout group and CJK text arrive |
| `wpa_supplicant-holo` | `wpa_supplicant` | a WPA3 (SAE) "unspecified failure" counts as a wrong password; two fixes against forced rescans after resume (hostap `20e1762ee`, `ab3200b10`, merged upstream, not released yet); built with WNM, MBO, OCV, FILS, the learning background scan, autoscan and 802.11be, as Valve's build |
| `iwd-holo` | `iwd` | a scan of some channels keeps the list of known access points; the access point being joined stays in it; scans are cancelled before connecting; only the bands the adapter supports are scanned (SteamOS 3.9.3) |
| `mesa-holo` | `mesa` and all its subpackages (`mesa-dri`, `mesa-vulkan-radeon`, `libgbm`, ...), with their `-32bit` packages | OpenGL: Steam's frame limit through gamescope's limiter file (DRI3: the patch turns V-Sync on while a limit is set; confirmed with glxgears and V-Sync off: 30.0 FPS at limit 30, uncapped without a limit). RADV: explicit synchronisation for VM operations, per command buffer BO tracking and no global BO list for gamescope (stutter in game mode), `VK_EXT_pageable_device_local_memory`, *Forza Horizon* 4 to 6; three RADV fixes from Mesa main that are not in 26.2.5 |
| `xdg-desktop-portal-kde-holo` | `xdg-desktop-portal-kde` | Steam may share the screen without Plasma's dialog when it has no saved choice (Valve's patch, xdg-desktop-portal-kde 6.7.3-1.2, SteamOS 3.9.3); Io's own: Steam recognised by its client binary, since without systemd the portal passes no app id |

Valve's other patches to these packages are left out: for bluez, the
`main.conf` settings (Io sets them in its own file), the wake-policy
plugin and LL privacy (no effect on SteamOS 3.9.2), test changes; for
NetworkManager, the iwd backend patches including the SAE type pair with
iwd and the migration patches that mirror connections into iwd
(wpa_supplicant is the backend; decided 2026-10-21);
for kwin, the `WM_TAKE_FOCUS` fix (already in 6.7.5); for Xwayland, the two
reverts Valve carries for a seamless start of Steam (on Io they caused a
black flash when returning to game mode; without them the desktop's last
picture stays until Steam's boot animation, as on SteamOS); for
wpa_supplicant, Arch's patches in Valve's build and the rest of Valve's
build options (among them PC/SC and SIM authentication, which would need
`pcsclite`); WEP stays enabled as in Void's build (Valve's leaves it off);
for Mesa, `radv: always consider some outputs as invariant` (in 26.2.5
already), CI files and Valve's pick script.

---

## System updates

SteamOS updates its read-only image atomically (A/B partitions,
`atomupd-daemon`, RAUC). Io updates packages with xbps, behind the same
interfaces Steam uses:

- **`/usr/bin/steamos-update`** behaves like Valve's script: `check` answers
  0 with a build id, 7 without an update, 8 when an update was applied and
  a reboot is pending; applying prints progress the way `atomupd-manager`
  does and ends with *Update completed*. The build id has SteamOS's form
  but means something else: the date and the number of pending packages
  (`20261005.12`). `xbps` itself is updated first when it is outdated.
- **`com.steampowered.Atomupd1`** (interface version 8) is served by
  `io-atomupd`, a runit service: the proxy methods (a proxy set in
  Steam is used for xbps's downloads), `CheckForUpdates`, `StartUpdate` and
  the properties. One variant (`steamdeck`) and one branch (`stable`).
  Pausing and cancelling are refused: xbps cannot be stopped safely in the
  middle of a transaction. Access is limited to root and `wheel`, as for
  SteamOS Manager (Valve: anyone, with polkit per method).
- Every update is logged to `/var/log/io-update.log`. An update does not
  restart running services; the reboot Steam asks for does.
- **Patch notes are Valve's.** When an update is offered, Steam shows the
  newest patch notes event of Valve's Steam Deck app (1675200) for the
  update channel (stable, beta or preview, from the OS branch and the
  client's beta), not notes that belong to the update. So Io's updates come
  with SteamOS's latest notes. Only Valve can post there, and Io does not
  change Steam's client.

---

## Storage

- **Automount** is Valve's: its udev rule, `block-device-event.sh` and
  `steamos-automount.sh`, with udisks mounting the drive for `deck`
  (`/run/media/deck/<label>`). The rule starts the scripts through
  `io-detach` (`setsid --fork`, output to syslog and `/run/io-detach.log`)
  instead of `systemd-run`. A drive seen before the system bus exists (at
  boot) waits up to 10 minutes for it; Valve asks `systemctl` whether the
  system is up.
- **The disk Io runs from is never automounted.** Valve's scripts leave
  SteamOS's own partitions out by their partition sets; Io's check asks
  which disk `/` is on and leaves that whole disk alone, and also any drive
  when it cannot tell.
- **The internal SSD is hidden from udisks** (`UDISKS_IGNORE`,
  `UDISKS_SYSTEM`) while Io runs from another disk, since it holds a system
  of its own, SteamOS or an installed Io (Io's
  `90-io-hide-internal-disk.rules`). Steam leaves it out of its
  storage list at start, but lists it again after a USB drive is plugged
  in, most likely from udisks' drive object, which unlike the disk and its
  partitions cannot be hidden. Accepted; the only thing Steam offers for it
  is formatting, and Valve's `format-device.sh` refuses NVMe drives.
- **Trimming** runs Valve's `trim-devices.sh`. For an SD card Valve
  considers unsafe to trim, SteamOS trims `/var` and `/home` on the
  internal SSD instead; Io may run from that card, so it trims every ext4
  or btrfs filesystem mounted read-write except those on the card (not yet
  needed on the test Deck: its card is safe to trim).
- **Formatting from Steam** runs Valve's helpers and `format-device.sh`,
  with an Io check that refuses the disk `/` is on: Valve's device list
  takes any SD card or USB drive, and Io runs from one. Tested
  (2026-10-19): the internal SSD refused while Io ran from the card, an SD
  card and a USB drive formatted (validation with f3probe, ext4, mounted
  for deck), as on SteamOS.

---

## Factory reset

SteamOS resets an A/B system: for the user data its initramfs formats the
`/home` and `/var` partitions at the next boot (`/etc` lives in `/var`
there, so every setting goes too); for the OS, `steamos-reset-tool`
installs a fresh image from Valve's update server into the other slot.
Steam's client on SteamOS 3.9.3 runs, as the user, `steamos-reset-tool
os-status` and then `steamos-reset-tool factory-reset --reset-os
--reset-user-data` (Valve's tool reaches its root backends through a setuid
wrapper), then restarts the Deck itself; `FactoryReset1.PrepareFactoryReset`
(1 user data, 2 OS, 3 both) and the helper `steamos-factory-reset-config`
still exist but were not called. Io has one root filesystem and no slots,
so `io-factory-reset` does it in place, behind all three: Io's
`/usr/bin/steamos-reset-tool` answers as Valve's (JSON on stdout) and gets
root through polkit instead of a setuid wrapper (no password in the active
local session, an admin's otherwise).

- **User data**, at the next start, before any service (core service
  `04-io-factory-reset.sh`; SteamOS's initramfs runs at the same point):
  `/home` and `/root` emptied, deck's home made new from `/etc/skel`, other
  people's accounts removed; Wi-Fi and Bluetooth pairings, Flatpaks, logs
  and caches in `/var` deleted; the settings Steam and the user change in
  `/etc` set back to the image's (hostname, time zone, language, passwords,
  deck's groups, Wi-Fi connections, backend and power saving, SDDM's login
  mode, SSH host keys, machine-id, and the services Steam switches: SSH on;
  developer mode and iwd off; the LAVD scheduler and EC logging linked with
  their `down` file, as installed); a hibernated session is
  dropped; shadow's backup files (`/etc/passwd-` and the like, with the old
  password hashes) and sudo's first-use marks are removed; the update
  channel goes back to the image's (the repository files in `/etc/xbps.d`,
  such as Io's testing channel, are removed): SteamOS keeps its branch in
  `/var`, which its reset formats, and falls back to stable. The image's
  values come from `/var/lib/io/factory-defaults`,
  written by `mkrootfs.sh`; older installations get the build defaults.
  Everything else in `/etc` stays as it is: unlike SteamOS, Io cannot tell
  a changed system file in `/etc` from one an update brought.
- **OS**, right away while the system runs (it needs the network): the
  system is updated, packages installed on top of Io are removed (those
  Io's packages need stay), every package whose files were changed or
  deleted is installed again (`xbps-pkgdb -a`), and `/usr/local` is
  emptied. Packages whose installed version is not the repositories'
  (from another channel, or built by hand) are installed again from the
  repositories, even where that is older. With both parts the channel is
  reset first, so the system ends on the default channel's versions, as
  SteamOS installs the stable image; the OS part alone keeps the channel.
  Steam's call waits until this is done, as it waits for
  Valve's download of the new image; whether Steam's client gives up
  earlier is one of the things to test.
- Steam's helper `steamos-factory-reset-config` needs no password only in
  the active local session (Steam); Valve's policy lets any caller
  schedule the wipe.
- Like SteamOS, an interrupted user-data reset is started again at the
  next start until it completes.
- From a terminal: `io-factory-reset` asks first and restarts;
  `--status` and `--cancel` for a pending reset. On the recovery stick,
  *Repair Io* can request the same reset for an Io that does not start.

**Tested** (2026-10-20, Io on the NVMe): Steam's factory reset restarts the
Deck, the user data is erased at the start, Steam's first setup follows,
the update channel is back to the image's. The Wi-Fi backend stays
wpa_supplicant, the default since SteamOS 3.9.2 (Valve's
`10-steamos-defaults.conf`); Steam's setup does not change it. Again on
2026-10-26 with Valve's steamos-manager (`io-factory-reset` 0.2.1_3).

---

## Not present on Io

Atomic A/B updates (`steamos-atomupd`, `rauc`, `holo-desync`,
`steamos-efi`; Io updates with xbps, see *System updates*), Valve's reset
tool (`steamos-reset`; Io has its own, see *Factory reset*), the crash log
submitter, Valve's nested desktop (Plasma inside game mode), and the VRAM
priority for the foreground game (`dmemcg-booster`, `kcgroups`,
`plasma-foreground-booster`: driven by systemd's units and slices; decided
not to implement on 2026-10-03: `dmemcg-booster` protects the user's
`app.slice` and `user@` service against the system, session and
background slices, and on Io nothing else competes for VRAM in game
mode). The full list, package by package, is on
[SteamOS packages](Valve-Package-Survey).
