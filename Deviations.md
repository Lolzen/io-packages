# Deviations from SteamOS

Reference: SteamOS 3.8.4 on the same Steam Deck LCD, captured in September
2026 (process environments and capabilities, SteamOS Manager D-Bus values
and calls, sysfs, systemd units, configuration files). Everything not listed
here is meant to behave as on SteamOS; a difference that is not on this page
is a bug.

---

## Design choices

| Io | SteamOS | Why |
|---|---|---|
| Void Linux with runit | Arch Linux with systemd | The point of the project |
| Writable root file system, software through xbps | Read-only root, A/B images, atomic updates | Simpler, and lets users install anything from Void's repositories. A/B updates are a possible post-1.0 goal |
| No Flatpak, no Discover; OctoXBPS as graphical package manager | Flatpak through Discover | SteamOS needs Flatpak because its root is read-only. Io does not; Flatpak can still be installed by hand |
| Steam Deck LCD (Jupiter) only | LCD and OLED (Galileo) | No OLED hardware to test with |
| Disk image written with `dd` | Recovery image with installer | Fixed hardware, nothing for an installer to ask. The live ISO route is blocked by a dracut/void-mklive incompatibility |
| Io-branded boot splash and update screen | SteamOS logo | Valve's logos are Valve's trademarks; Io does not ship them |
| Io's own messages are English only, not localized | Localized | One-person project; English as the common denominator |
| SSH server enabled out of the box, user `deck` with password `deck` | SSH off; enabled through Steam's developer settings, no password until the user sets one | Needed during the test phase. Images for 1.0 will follow SteamOS |

---

## Login and sessions

- **SDDM as on SteamOS**, with the same autologin and `Relogin`, run as
  the runit service `io-sddm`. Its settings are Io's own
  (`/usr/lib/sddm/sddm.conf.d/10-io.conf`), with the Wayland greeter on
  kwin. Each session runs `io-start` under its own `dbus-run-session`;
  SteamOS uses systemd user units instead.
- **The desktop session is `io-desktop.desktop`**, not Plasma's own
  `plasma.desktop`: it runs Io's session setup (PipeWire, the filter chain,
  Steam's DPI setting) before Plasma, which SteamOS does through user
  services. `SessionManagement1` accepts Plasma's session names and maps
  them to it.
- **gamescope starts Steam as its child.** SteamOS runs gamescope and Steam
  as two systemd units and passes the display names through a startup socket
  (`-R`); Io does not need it. The statistics pipe (`-T`) is set as on
  SteamOS.
- **Steam launch flags, gamescope arguments and environment match
  SteamOS**, except variables whose counterpart Io does not have yet
  (drive adoption and unmounting through Steam, systemd scopes). Setting them would show controls in Steam that do nothing.
- **HDMI-CEC:** `cecd` starts through D-Bus activation and
  `cec-audio-control` directly from the session scripts (SteamOS: user
  services of the graphical session, `cec-audio-control` socket-activated).
  Access to `/dev/cec*` and `/dev/uinput` comes from group rules (`video`,
  `input`) instead of systemd's `uaccess`.
- **Logging out ends every process of the session**, as on SteamOS
  (`KillUserProcesses`), set in elogind.
- **mangoapp and gamemode** are started differently: mangoapp by the session
  script in a loop tied to gamescope (Valve: a user service with
  `Restart=always`), gamemode on demand through D-Bus (Valve: a service that
  always runs).
- **The text console stays on tty1** with a login prompt. SteamOS moves it
  to tty4–6 (`fbcon=vc:4-6`). The sessions run on tty7 either way.
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
- **Not implemented**, for lack of a counterpart on Io: `Storage1`, `Jobs`,
  `UdevEvents1`, `UpdateBios1`, `UpdateDock1`, `FactoryReset1`.
  `WifiDebug1` is not needed: SteamOS 3.8.4 does not offer it on the Deck.
- **`ScreenReader0/1`** starts Orca itself (SteamOS: `orca.service` with
  gamescope's environment file), with the running Steam's display settings.
  When it writes Orca's settings file before Orca ever ran, it adds the
  sections Orca needs (Orca would otherwise stop at start).
- **`Audio1`** sets WirePlumber's `node.features.audio.mono` with `wpctl`.
- **`CpuScheduler1`** switches `scx_lavd` through a runit service `scx` in
  place of SteamOS's `scx.service`, with Valve's `/etc/default/scx`.
- **Wi-Fi backend:** wpa_supplicant by default, as in Valve's current
  configuration; SteamOS 3.8.4 still defaults to iwd. Switching works in
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
- **Hibernation is allowed only with `/` on the internal NVMe** (Io's own
  core service writes elogind's `sleep.conf.d`). Suspend-then-hibernate is
  not set up yet.
- **Time sync through chrony**: Void has no `systemd-timesyncd`.
- **Hostname `io`** (SteamOS: `steamdeck`), set by `mkimg.sh`.
- **`iio-sensor-proxy`** is installed and running; SteamOS 3.8.4 does not
  ship it.
- **earlyoom** runs with Valve's full argument set; its `--avoid` list names
  runit's processes instead of systemd.
- **`tmpfiles.d` rules** from Valve's packages are boot-time core services
  (`holo-dmi-rules`, `holo-fstab-repair`), since Void has no tmpfiles.
- **`CAP_SYS_NICE` for gamescope** is set as a file capability, exactly as
  on SteamOS, but by a boot-time core service, because gamescope comes from
  Void's package and an update would drop it.
- **Boot splash** is ended by `io-sddm` right before SDDM starts. There is no
  controller firmware update splash (`plymouth-wrap`), since Io has no
  controller update service.
- **Initramfs:** dracut loads the SD card modules before `amdgpu` on
  purpose, so card detection overlaps `amdgpu`'s load (about 3.7 s on its
  own).

---

## Kernel

- **`linux-neptune-72`, 7.2.4**, built from Valve's `linux-integration` tree
  on top of Void's base configuration with Valve's `config-neptune` fragment
  merged in. SteamOS 3.8.4 runs 6.16.
- **Kernel command line** matches SteamOS except `fbcon=rotate:1` instead of
  `fbcon=vc:4-6` (see *Login and sessions*), no `console=tty1`, and none of
  the systemd- and A/B-specific options (`rd.systemd.gpt_auto`, `fsck.*`,
  `steamos.efi`). Io adds `net.ifnames=0`: SteamOS's Wi-Fi interface is
  `wlan0` as well, while Void's udev would rename it (see *Pitfalls*).
- **No reboot on kernel panic.** SteamOS's panic sysctls are left out during
  the alpha phase: Valve pairs them with a crash log submitter, and without
  one a frozen device is more useful for debugging.

---

## Audio (`steamdeck-dsp`)

- **Noise suppression plugin:** Valve uses NoiseTorch's RNNoise LADSPA
  plugin (label `nt-filter`). Io builds werman/noise-suppression-for-voice as
  `rnnoise-ladspa` (label `noise_suppressor_mono`), because Void's NoiseTorch
  package ships no system-wide plugin.
- **Version:** Io builds Valve's `steamdeck-dsp` 1.02; SteamOS 3.8.4 runs
  0.91. Differences that matter are listed here; 0.91's
  `session.suspend-timeout-seconds = 0` on the microphone filter's node is
  not in 1.02 and not in Io.
- **No hardware profile switching.** SteamOS picks the audio profile for the
  Deck model at boot through symlinks in `/run`. Io only supports Jupiter and
  installs its configuration directly into the standard search paths.
- **ALSA loopbacks** are created by an Io WirePlumber script that rebuilds
  Valve's `CreateLoopback()`, which only exists in Valve's patched
  WirePlumber. The result matches SteamOS, including the card identity the
  loopback carries — that is what makes Steam show its own localized device
  names.
- **Sources and sinks get a loopback**, as on SteamOS 3.8.4
  (`steamdeck-dsp` 0.91); Valve's 1.02 marks only sources, Io adds the sink
  rule back (`91-io-sink-loopback.conf`). The sink
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
  Valve's source. SteamOS 3.8.4 runs 3.16.23.
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
- **`cecd`** is 0.2.0 and **`cec-audio-control`** 0.1.0, the versions of
  SteamOS 3.8.4, built from Valve's newer source archives.
- **`vpower`** is patched to find the `steamdeck-hwmon` directory instead of
  assuming `hwmon3`; **`holo-upower-config`** has `yes` changed to `true`
  so that UPower actually honours it.
- **`deck-hw-support`** is Valve's `jupiter-hw-support` 20260807.1 with the
  helpers under their `steamos-*` names: that version renames them to
  `holo-*` (Valve's `steamos-alias` links them back); SteamOS 3.8.4 itself
  still runs 20260327.1 with the old names. The cursor images come from
  20260327.1, later versions moved them to another package. Several helpers
  are stubs, see [Helper status](Helper-Status). The automount udev rules
  are disabled.
- **`steamos-priv-write`** gives the written files to the `wheel` group
  instead of `deck`, because the user name is chosen when the image is built
  (`USERNAME` in `mkimg.sh`), and logs through `logger`.
- **`xdg-desktop-portal-gamescope`** no longer aborts when there is no
  journald to log to.
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
  `rp_filter` and `promote_secondaries` (values as captured on SteamOS
  3.8.4).
- **`holo-fstab-repair`** runs Valve's script on every boot; SteamOS runs it
  only when the user changed `fstab` in its `/etc` overlay, which Io does
  not have.
- **Newer than SteamOS 3.8.4:** several Valve packages are built from newer
  source archives than SteamOS 3.8.4 carries — `steamdeck-dsp` 1.02 (0.91),
  `vpower` 1.6.3 (1.5.7), `steamdeck-kde-presets` 3.9.4 (3.8.5),
  `xdg-desktop-portal-gamescope` 0.1.38 (0.1.33), `jupiter-fan-control`
  20260902.1 (20260422.2), `holo-fstab-repair` 0.2 (0.1),
  `steam-jupiter-stable` -12 (-8; adds `-pipewire` to Steam's command line)
  and `holo-upower-config` (not on SteamOS 3.8.4).
- **`steamos-systemreport`** reads socklog and Io's session logs instead of
  the journal, and checks packages with xbps instead of pacman.
- **`timedatectl`** is a small replacement script; Steam only uses
  `set-timezone`.
- **ALSA's default device** is routed through PipeWire by links `io-base`
  ships. Void leaves enabling `alsa-pipewire` to the admin; SteamOS has it
  out of the box.

---

## Not present on Io

System updates (`steamos-atomupd`, `holo-desync`, `steamos-efi`), BIOS and
dock firmware updates, factory reset (`steamos-reset`), controller firmware
updates, the crash log submitter, Valve's nested desktop (Plasma inside game
mode), automount of SD cards and USB drives (Alpha 5), the holo portal
(`xdg-desktop-portal-holo`: Settings and app chooser in game mode; Io's
`gamescope-portals.conf` says `default=gamescope` instead of
`default=holo;gamescope`), `steam_notif_daemon` (Steam's notifications in
game mode), `drm_janitor`, `dmemcg-booster` (needs `CONFIG_CGROUP_DMEM`,
which Io's kernel lacks) and the low-disk cleanup at the start of Valve's
`gamescope-session` (deletes the oldest game when less than 500 MB are
free). The dock updater is a
stub that tells Steam the dock is up to date. Not needed on Io at all: `holo-keyring` (pacman keys),
`holo-nix-offload` (Nix store), `holo-nfs-utils-tmpfiles` (NFS).
