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
| Steam Deck LCD (Jupiter) only | LCD and OLED (Galileo) | No OLED hardware to test with |
| Disk image written with `dd`; a recovery stick with an installer exists, installing is not released yet ([Installation](Installation)) | Recovery image with installer | Fixed hardware, nothing for an installer to ask. The recovery stick is a plain writable Void system instead of a live ISO: self-built live ISOs stop in dracut's emergency shell (cause not found) |
| Io-branded boot splash and update screen | SteamOS logo | Valve's logos are Valve's trademarks; Io does not ship them |
| Io's own messages are English only, not localized | Localized | One-person project; English as the common denominator |
| GRUB boots Io without its menu; *Restart* from Io starts Io again (UEFI `BootNext`), switching on starts the firmware's default system | `steamcl` without a menu, SteamOS on the internal SSD is the firmware's default | Io on an SD card has no boot entry of its own (GRUB at the removable path), so a restart started the internal SteamOS. `BootNext` lasts one boot, so SteamOS stays the default. A boot that goes wrong ends in dracut's emergency shell; the recovery stick keeps its menu |
| SSH server enabled out of the box, user `deck` with password `deck` | SSH off; enabled through Steam's developer settings, no password until the user sets one | Needed during the test phase. Images for 1.0 will follow SteamOS |

---

## Login and sessions

- **SDDM as on SteamOS**, with the same autologin and `Relogin`, run as
  the runit service `io-sddm`. Its settings are Io's own
  (`/usr/lib/sddm/sddm.conf.d/10-io.conf`), with the Wayland greeter on
  kwin. Each session runs `io-start` under its own `dbus-run-session`;
  SteamOS uses systemd user units instead. Valve's SDDM file also sets
  `InputMethod=qtvirtualkeyboard`; Io leaves it out, since it is SDDM's
  default and SDDM 0.21 drops it for a Wayland greeter anyway.
- **The desktop session is `io-desktop.desktop`**, not Plasma's own
  `plasma.desktop`: it runs Io's session setup (PipeWire, the filter chain,
  Steam's DPI setting) before Plasma, which SteamOS does through user
  services. `SessionManagement1` accepts Plasma's session names and maps
  them to it. Because it reports this one session, Steam's developer page
  shows a session menu with one entry instead of *Use Legacy X11 Desktop
  Mode* (shown only for exactly `plasma.desktop` and `plasmax11.desktop`);
  Io has no X11 desktop session.
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
- **HDMI-CEC:** `cecd` starts through D-Bus activation and
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
- **The text console stays on tty1** with a login prompt. SteamOS moves it
  to tty4–6 (`fbcon=vc:4-6`). The sessions run on tty7 either way.
- **The desktop keeps the brightness set in game mode.** `io-plasma` writes
  the current backlight into the internal panel's entry of kwin's
  `kwinoutputconfig.json` before kwin starts. Valve patches kwin for the
  same result (KDE bug 508163); Io gets it without a kwin build.
- **On-screen keyboard in the desktop:** `plasma-keyboard`, as SteamOS 3.9.2
  (it replaced Maliit there). As on SteamOS it is not set as kwin's input
  method by default; System Settings → Keyboard → Virtual Keyboard turns it
  on. The recovery stick's build sets it (it opens on touch only).
- **Screen sharing permission in the desktop:** Steam asks Plasma's portal
  for screen sharing when it starts in the desktop; the answer is kept with
  a restore token. Io stores it for an app without an ID (`""`), SteamOS for
  `steam`, most likely because without systemd the portal cannot name
  Steam from a cgroup scope. Neither system grants it in advance
  (`kde-authorized` empty on both), so a new user should be asked once on
  either; not tried yet on a fresh user (see [Milestones](Milestones)).
- **Touch only with the dock:** SteamOS switches the trackpads and the
  pointer off while the dock is attached and leaves only the touchscreen
  (seen with a mirrored display); Io leaves them on. Not looked into yet.
- **Session output goes to a rotating log** (`/run/user/1000/io-log-<session>/`,
  or `~/.local/state/io/` while Steam's developer mode is on) instead of
  the systemd journal.

---

## SteamOS Manager

`io-steamos-manager` is Io's own Python implementation of
`com.steampowered.SteamOSManager1`. Valve's Rust daemon depends on systemd
throughout. The structure is the same as Valve's: a root half on the system
bus (runit service) that does all privileged work, and a session half on
the session bus that Steam talks to.

- **Access to the root half** is limited to root and the `wheel` group.
  Valve allows any local user.
- **Values match SteamOS** (TDP 3–15 W, GPU power profiles `CAPPED` and
  `UNCAPPED`), except the desktop session name (`io-desktop.desktop`, see
  *Login and sessions*).
- **`SessionManagement1`** writes the same SDDM files as steamos-manager
  (`zz-steamos-autologin.conf`, `zzt-steamos-temp-login.conf`) through the
  root half, and logs Plasma out through `org.kde.Shutdown`.
- **`Storage1`** runs as steamos-manager 26.1.0 does: `TrimDevices` starts
  Valve's `trim-devices.sh` as a job (`Job1`, announced by `JobManager1`)
  on the root half, mirrored for Steam on the session bus. Differences: the
  session half mirrors the jobs it started itself (Valve's also picks up
  every root job already running when it starts); `Job1.ExitCode`, declared
  in Valve's interface file but not implemented in 26.1.0, works; the root
  half numbers its jobs from the time it started, so a number is not
  reused after a restart. `FormatDevice` answers `NotSupported` until
  formatting is ported and tested (see *Storage*).
- **Not implemented**, for lack of a counterpart on Io: `UdevEvents1`,
  `UpdateBios1`, `UpdateDock1`, `FactoryReset1`.
  `WifiDebug1` is not needed: SteamOS does not offer it on the Deck (3.8.4
  and 3.9.2).
- **HDMI-CEC (`HdmiCec1`, `HdmiCec2`)** as in steamos-manager 26.4.1: the
  switches Steam sets go into `cecd`'s configuration, and `cecd` reloads it
  through its own D-Bus interface (`Config1.Reload`). Io keeps its own copy
  of the four settings in `99-steamos-manager.toml` instead of rebuilding
  the file from a cache, as Valve does. `WakeDevice` is unsupported (false),
  as on the LCD under SteamOS. `MakeActive` asks `cecd` to wake the TV.
- **Download mode** stops the OS fan control through runit, sets the fan to
  2000 rpm (`fan1_target`) and starts fan control again afterwards, in
  Valve's order; the root half waits until runit has really stopped the fan
  service (`sv -w`), whose `finish` script would otherwise reset the fan
  after Io set it.
- **`com.steampowered.Atomupd1`**, atomupd-daemon's update API (interface
  version 8), is served by the root half with xbps behind it; see
  *System updates*. Steam itself only calls its proxy methods.
- **`ScreenReader0/1`** starts Orca itself (SteamOS: `orca.service` with
  gamescope's environment file), with the running Steam's display settings.
  When it writes Orca's settings file before Orca ever ran, it adds the
  sections Orca needs (Orca would otherwise stop at start).
- **`CpuScheduler1`** switches `scx_lavd` through a runit service `scx` in
  place of SteamOS's `scx.service`, with Valve's `/etc/default/scx`.
- **Wi-Fi backend:** wpa_supplicant by default, as Valve ships SteamOS
  3.9.2 (3.8.4 still defaulted to iwd; the captured Deck runs iwd because
  it was switched in Steam's settings). Switching works in
  both directions. iwd runs as a runit service linked only while it is the
  backend.
- **Wi-Fi power save** goes into a file of Io's own
  (`99-io-wifi-powersave.conf`) and into iwd's `main.conf`. Valve keeps it
  in `99-valve-wifi-backend.conf`, which Valve's own backend switch
  rewrites, losing it; and NetworkManager does not pass it on to iwd.
- **Connectivity check** against GNOME's endpoint; SteamOS uses Arch's.

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
- **Hibernation is allowed only with `/` on the internal NVMe and `resume=`
  on the kernel command line** (Io's own core service writes elogind's
  `sleep.conf.d`); without a resume path a hibernated session would be
  lost. SteamOS 3.9.2 allows hibernation and suspend-then-hibernate (delay
  20 minutes, counted only on battery); 3.8.4 switched it off ("disabled for
  3.8.x cycle"). Not set up on Io yet.
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
- **Boot splash** is ended by `io-sddm` right before SDDM starts. There is no
  controller firmware update splash (`plymouth-wrap`), since Io has no
  controller update service.
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
- **No reboot on kernel panic.** SteamOS's panic sysctls are left out during
  the alpha phase: Valve pairs them with a crash log submitter, and without
  one a frozen device is more useful for debugging.

---

## Graphics

- **Mesa is Void's** (26.2.x), not Valve's (SteamOS 3.9.2: radeonsi 26.1.2,
  RADV from Valve's `steamos-26.05` branch; analysed on 3.8.4's radeonsi
  25.3.0 with one Valve patch and RADV `steamos-25.11.12`). Missing as a result:
  - Valve's frame limiter for OpenGL through gamescope
    (`GAMESCOPE_LIMITER_FILE`, DRI3): **OpenGL games most likely ignore
    Steam's FPS limit** (from Mesa's source; to be confirmed with a game).
    Vulkan games are limited through gamescope's WSI layer.
  - RADV's game fixes that only exist in Valve's branch: NGG culling off
    for *No Rest for the Wicked*, `vk_x11_override_min_image_count=4` for
    *Forza Horizon 5*.

  Why: Io would have to rebuild Mesa, with its 32-bit build, on every Void
  update; the gain does not justify that (decided 2026-10-03).
- **gamescope's WSI layer for 32-bit games** is Io's `gamescope-wsi-32bit`,
  built from gamescope's source (SteamOS: `lib32-gamescope`). Void builds
  gamescope for 64 bit only.

---

## Audio (`steamdeck-dsp`)

- **Noise suppression plugin:** Valve uses NoiseTorch's RNNoise LADSPA
  plugin (label `nt-filter`). Io builds werman/noise-suppression-for-voice as
  `rnnoise-ladspa` (label `noise_suppressor_mono`), because Void's NoiseTorch
  package ships no system-wide plugin.
- **Version:** `steamdeck-dsp` 1.02, as on SteamOS 3.9.2 (3.8.4 ran 0.91,
  which kept the microphone filter from suspending; 1.02 drops that, and Io
  follows).
- **UCM profile:** Valve's profile from `steamdeck-dsp` (`Internal Mic`,
  headphone sink), as on SteamOS. Void's `alsa-ucm-conf` also ships
  `conf.d/acp5x/Valve-Jupiter-1.conf`, which UCM would pick first by the
  card's long name; `steamdeck-dsp` keeps it out (`noextract`).
- **No hardware profile switching.** SteamOS picks the audio profile for the
  Deck model at boot through symlinks in `/run`. Io only supports Jupiter and
  installs its configuration directly into the standard search paths.
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
- **OLED (Galileo) firmware removed**, its UCM profile kept (two small files,
  a head start for anyone porting Io to that model).

---

## Other ported packages

- **`steam-jupiter`** replaces Void's `steam` as Valve's package replaces
  Arch's. Its dependency list is Void's plus Valve's additions, in Void's
  names; the standard Steam udev rules keep coming from Void's
  `steam-udev-rules`. Arch's `lib32-pipewire` becomes `pipewire-32bit` plus
  every `libspa-*-32bit`, which Void ships separately.
- **gamescope** is Void's, 3.16.30 (Io's update to Void), built from
  Valve's source, the version SteamOS 3.9.2 runs as well.
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
  see *Storage*. `99-sdcard-rescan.rules` stays disabled (it needs
  `systemd-run`, and has nothing to do while Io boots from the card).
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
  *Return to Gaming Mode* calls `steamos-session-select` (Valve:
  `steamosctl`); IBus uses Void's panel path under `/usr/libexec`. Left out:
  the X11-only IBus environment, the nested desktop, Valve's menu overrides
  in `/usr/local` and its Firefox desktop file.
- **Steam's DPI scaling in the desktop** is switched off once per user by
  `io-plasma` (`DPIScaling` 0). Plasma keeps its own 135 %.
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
  raises at start. Valve's suspend-then-hibernate settings are not taken
  over (see *System services*, hibernation).
- **`holo-fstab-repair`** runs Valve's script on every boot; SteamOS runs it
  only when the user changed `fstab` in its `/etc` overlay, which Io does
  not have.
- **Versions:** the ported Valve packages are the versions of SteamOS
  3.9.2 ([SteamOS packages](Valve-Package-Survey)).
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
- **Umlauts in game mode:** Steam's keyboard types them on Io, but not on
  SteamOS 3.9.2 (system language English, German keyboard); why was not
  looked into.

---

## Io overlay

Where Io needs a patch Valve carries in a package Void also has, it builds
Void's package with the patch as a package of its own, `<name>-holo`, that
replaces Void's (the build is described in io-packages'
[overlay/README.md](https://github.com/Lolzen/io-packages/blob/main/overlay/README.md)).
Void's `-32bit` packages of these stay Void's.

| Package | Replaces | Valve's patches carried |
|---|---|---|
| `MangoHud-holo` | `MangoHud`, `MangoHud-mangoapp` | mangoapp draws once per game frame (MangoHud `2c1dc52`, after 0.8.4; Void's 0.8.4 draws continuously) |
| `NetworkManager-holo` | `NetworkManager`, `libnm`, `NetworkManager-devel` | after resume, scan only the last-associated frequency (MR 2514, not merged) |
| `bluez-holo` | `bluez`, `libbluetooth` and the other bluez packages | a re-paired device's old entry with the same key is removed (Steam Controller and suspend); the Switch Pro Controller's link may use sniff mode. Built with `-std=gnu17`: Void's autoconf 2.73 makes bluez 5.86 compile as C23, where it fails |
| `ibus-anthy-holo` | `ibus-anthy` | Valve's fork of 1.5.14 (Void: 1.5.16, Valve's changes do not apply to it); not generated from Void's template |

Valve's other patches to these packages are left out: for bluez, the
`main.conf` settings (Io sets them in its own file), the wake-policy
plugin and LL privacy (no effect on SteamOS 3.9.2), test changes; for
NetworkManager, the iwd backend patches (wpa_supplicant is the backend).

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
  `io-steamos-manager`'s root half: the proxy methods (a proxy set in
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
  `UDISKS_SYSTEM`) while Io runs from another disk, since it holds SteamOS
  (Io's `90-io-hide-internal-disk.rules`). Steam leaves it out of its
  storage list at start, but lists it again after a USB drive is plugged
  in, most likely from udisks' drive object, which unlike the disk and its
  partitions cannot be hidden. Accepted; the only thing Steam offers for it
  is formatting, and Valve's `format-device.sh` refuses NVMe drives.
- **Trimming** runs Valve's `trim-devices.sh`. For an SD card Valve
  considers unsafe to trim, SteamOS trims `/var` and `/home` on the
  internal SSD instead; Io may run from that card, so it trims every ext4
  or btrfs filesystem mounted read-write except those on the card (not yet
  needed on the test Deck: its card is safe to trim).
- **Formatting from Steam is not available yet**: `FormatDevice` answers
  `NotSupported` until formatting is ported and tested, the format helpers
  are stubs. Valve's `format-device.sh` is in place with an Io check that
  refuses the disk `/` is on: Valve's device list takes any SD card or USB
  drive, and Io runs from one.

---

## Not present on Io

Atomic A/B updates (`steamos-atomupd`, `rauc`, `holo-desync`,
`steamos-efi`; Io updates with xbps, see *System updates*), BIOS and
dock firmware updates, factory reset (`steamos-reset`), controller firmware
updates, the crash log submitter, Valve's nested desktop (Plasma inside game
mode), formatting drives from Steam (prepared, see *Storage*), and the VRAM
priority for the foreground game (`dmemcg-booster`, `kcgroups`,
`plasma-foreground-booster`: driven by systemd's units and slices; decided
not to implement on 2026-10-03: `dmemcg-booster` protects the user's
`app.slice` and `user@` service against the system, session and
background slices, and on Io nothing else competes for VRAM in game mode). The dock
updater is a stub that tells Steam the dock is up to date. The full list,
package by package, is on [SteamOS packages](Valve-Package-Survey).
