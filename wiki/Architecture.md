# Architecture

How Io works where it cannot simply do what SteamOS does. For the reasons
behind each difference, see [Deviations](Deviations).

---

## Boot

1. **GRUB** from Io's EFI partition, without showing its menu
   (`GRUB_TIMEOUT=0`, `GRUB_TIMEOUT_STYLE=hidden`, set by `io-base`). On an
   SD card from the image it is installed in removable mode without an
   NVRAM entry, because the card's partition GUIDs change with every image
   build. Installed with the recovery stick (`io-restore`), Io also gets an
   NVRAM entry, so the firmware starts it from that disk by default, as
   SteamOS's entry did; the removable path stays as a fallback. On
   *Restart* the shutdown hook `75-io-bootnext.sh` runs
   `/usr/libexec/io/io-bootnext`: it sets UEFI
   `BootNext` to the firmware's boot entry for the EFI partition Io started
   from (found by its PARTUUID; created once, outside `BootOrder`, if the
   firmware has none), so the next boot starts Io again. Switching off
   leaves `BootNext` alone; `IO_BOOTNEXT=no` in `/etc/default/io-bootnext`
   turns it off. Log: `/var/log/io-bootnext.log`.
2. **Initramfs** (dracut) with the `amdgpu` module included for early display, and
   Plymouth, which shows the Io splash from here on.
3. **runit stage 1** runs Void's core services, plus Io's own:
   - `04-io-factory-reset.sh` — a pending factory reset erases the user
     data here (`io-factory-reset`)
   - `20-dmi-serial-perms.sh` — DMI serial numbers readable by `wheel` only
   - `20-fstab-repair.sh` — comments out invalid SD card lines in fstab
   - `60-io-swapfile.sh` — Valve's 1 GiB swap file in `/home`
   - `62-jupiter-hibernate-disable.sh` — no hibernation on the Steam Deck
     (Valve's `jupiter-hibernate-disable`)
   - `61-io-hibernate-guard.sh` — hibernation allowed only with `/` on the
     internal NVMe
   - `70-io-cfs-tunings.sh` — mounts debugfs, applies Valve's scheduler tunings
   - `90-io-caps.sh` — `CAP_SYS_NICE` file capability on gamescope and
     `kwin_wayland`
   - `97-io-firmware-update.sh` — Valve's BIOS update (`--auto`) and
     controller update with its splash, as SteamOS runs them before the
     login manager
4. **runit stage 2** starts the services linked in `/var/service`, among them
   `steamos-manager` (root half), `io-atomupd`, `vpower`, `holo-zram-swap`,
   `earlyoom`, `jupiter-fan-control`, `socklog-unix` and `nanoklogd`,
   `jupiter-firewall`, `steam-web-debug-portforward`, and `io-sddm`. Steam's
   developer mode adds `avahi-daemon` and `steamos-devkit-service`.
5. **`io-sddm`** removes a leftover one-shot login file, ends the splash with
   `plymouth quit --retain-splash` (the screen goes from splash to black to
   game mode, as on SteamOS) and starts SDDM. SDDM logs `deck` in on tty7;
   tty1–6 are plain login consoles.

---

## Sessions

```
SDDM (autologin, Relogin)  →  gamescope-wayland.desktop  →  io-start gamemode  →  io-gamemode → gamescope → steam-launcher → steam-jupiter
                           →  io-desktop.desktop         →  io-start desktop   →  io-plasma   → startplasma-wayland
```

SDDM's settings are in `/usr/lib/sddm/sddm.conf.d/holo.conf` (Valve's name
for its own file, see *SteamOS Manager*): autologin
for `deck` into game mode, and a fresh login whenever a session ends
(`Relogin=true`), as on SteamOS. The login runs through PAM and elogind, so
each session is a real session on `seat0`; the memlock limit for the filter
chain comes from `/etc/security/limits.d/90-io-memlock.conf`, for the
`audio` group (the image build puts the user in it).

- **Steam** is started through `steam-jupiter`, Valve's Deck wrapper: it
  keeps Steam on the `steamdeck_stable` branch, adds `-steamdeck -pipewire`,
  and on first start sets Steam up from a preinstalled client. Network setup
  on first start is Steam's own first-run Wi-Fi page.
- **`io-start`** gets the session from the session file's `Exec` line and
  starts it under its own `dbus-run-session`. All output goes to a log, see
  *Logging*. The runtime directory and `XDG_RUNTIME_DIR` come from
  `pam_elogind` before SDDM starts it.
- **`io-gamemode`** reproduces Valve's `gamescope-session`: the same
  environment, gamescope arguments and Steam flags
  (`-steamos3 -steampal -steamdeck -gamepadui`), and the same low-disk check
  before start (under 500 MB free in the home directory, installed games are
  deleted, least recently changed first, until there is room; their
  `compatdata` stays). gamescope starts Valve's
  `steam-launcher` directly as its child; Valve's short-session tracker runs
  before and after it, as `steam-launcher.service` does. Like Valve's session
  it limits the portals to the game mode backends (`XDG_DESKTOP_PORTAL_DIR`:
  holo first, then gamescope), and passes gamescope's statistics pipe (`-T`,
  `GAMESCOPE_STATS`). It also starts PipeWire, the power button daemon,
  `io-manager-session` (SteamOS Manager's session half and cecd, see
  *SteamOS Manager*), the HDMI-CEC daemons, the filter chain's own PipeWire
  instance, Steam's
  notification daemon (`steam_notif_daemon`, which owns
  `org.freedesktop.Notifications` and hands each notification to Steam as a
  `steam://` link), and — right before gamescope, once the environment is
  complete — mangoapp for Steam's performance overlay, and once gamescope
  is up `ibus-daemon` for Steam's keyboard and, on the OLED, Valve's mura
  correction (`galileo-mura-setup`). It writes
  `$XDG_RUNTIME_DIR/gamescope-environment` for the screen reader, as Valve's
  session does. When gamescope exits,
  `drm_janitor` resets the display state before the next session takes the
  screen, as Valve's `ExecStopPost` does.
- **HDMI-CEC:** `cecd` is started through D-Bus activation
  (`StartServiceByName`, by `io-manager-session` after `steamosctl
  configure-cecd` has written its configuration), so there is only one way
  it comes up and the bus keeps it to one instance; `cec-audio-control` is
  started directly and
  creates its socket in `$XDG_RUNTIME_DIR` itself. Both in game mode and in
  Plasma, as SteamOS's user services of the graphical session.
- **Logging out ends the session's processes** (`KillUserProcesses=yes` in
  elogind, as on SteamOS): with SDDM a switch is a logout, and the session's
  bus, its daemons, PipeWire and anything started with `setsid` end with it.
  The next session starts its own PipeWire on its own bus.
- **`io-plasma`** starts KDE Plasma, with `io-manager-session` as in game
  mode. Steam starts there through XDG autostart (`steam -silent`, from
  `steamdeck-kde-presets`), as on SteamOS: it
  provides the on-screen keyboard in the desktop (Steam + X) and keeps hold
  of the controller. Before Plasma starts, `io-plasma` switches Steam's DPI
  scaling off once per user, so Steam draws in real pixels next to Plasma's
  135 %, and exports `STEAM_USE_WPASUPPLICANT=1`, as `io-gamemode` does, so
  Steam keeps the Wi-Fi backend in both modes (see [Deviations](Deviations)).

### Switching

As on SteamOS, `SessionManagement1` of steamos-manager tells SDDM which
session to log in next and ends the running one:

- **Game mode → desktop:** Steam calls `SwitchToDesktopMode`. The root half
  writes the one-shot file `/etc/sddm.conf.d/zzt-holo-temp-login.conf`
  (`zzt-steamos-temp-login.conf` while a file of that older name exists),
  the session half ends the login session through logind, and SDDM logs in
  with that file: Io's desktop. `steamosctl clean-temporary-sessions` in the
  new session removes the file again.
- **Desktop → game mode:** *Return to Gaming Mode* (Valve's `Return.desktop`)
  logs Plasma out through its own session manager (`org.kde.Shutdown`), and
  SDDM logs in to game mode, the default; with the desktop as default login
  mode it runs `steamosctl switch-to-game-mode` instead, which ends the
  session as above. The desktop's last picture stays on screen until
  Steam's boot animation, as on SteamOS.
- **Default login mode:** `DefaultLoginMode` writes
  `/etc/sddm.conf.d/zz-holo-autologin.conf` for a desktop default
  (`steamos-session-select plasma-wayland-persistent`) and removes it for
  game mode. `steamos-session-select` is Valve's `holo-session-select` with
  Io's desktop session (`io-desktop.desktop`) in place of Plasma's.
- **GPU reset:** the udev rule restarts `io-sddm`, as Valve's restarts SDDM:
  any session ends, and SDDM logs in fresh.

---

## SteamOS Manager

Io runs Valve's `steamos-manager` (`com.steampowered.SteamOSManager1`),
built from the branch `runit` of
[Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager):
Valve's main branch after 26.4.1 plus runit support, written to go to
Valve. At start it finds the init system: systemd when
`/run/systemd/system` exists, runit when PID 1 is `runit`. Booted with
systemd, nothing changes. Two halves, as on SteamOS:

| | Root half | Session half |
|---|---|---|
| Started as | runit service `steamos-manager` (`steamos-manager -r`) | D-Bus activation on the session's own bus, first by `io-manager-session` (SteamOS: the user unit `steamos-manager.service`) |
| Bus | system | session |
| Interfaces | `RootManager`, the jobs it runs | what Steam talks to, as Valve's device file and `platform.toml` decide; on the LCD `TdpLimit1`, `GpuPerformanceLevel1`, `GpuPowerProfile1`, `FanControl1`, `CpuScheduler1`, `SessionManagement1`, `LowPowerMode1`, `HdmiCec1`, `HdmiCec2`, `ScreenReader0/1`, `Storage1`, `UdevEvents1`, `UpdateBios1`, `UpdateDock1`, `FactoryReset1`, `WifiBackend1`, `WifiPowerManagement1`, ... |

Booted with runit, the daemon does without systemd:

- **System services:** a systemd unit name stands for the runit service of
  the same name (`jupiter-fan-control.service` → `/etc/sv/jupiter-fan-control`),
  started and stopped with `sv`; enabled means linked in `/var/service`
  without a `down` file. That covers fan control (`FanControl1`, download
  mode), the LAVD scheduler (`scx`, linked with a `down` file: supervised
  but not started at boot, as `scx.service` is installed but not enabled on
  SteamOS), EC logging on the Steam Machine (`ec-log`) and the Wi-Fi
  backends.
- **Wi-Fi backend (`WifiBackend1`):** NetworkManager is restarted with the
  new backend after the old one's D-Bus owner (`fi.w1.wpa_supplicant1`,
  `net.connman.iwd`) has ended; iwd runs as a runit service linked only
  while it is the backend, wpa_supplicant through D-Bus activation. Wi-Fi
  debug mode (OLED only) runs iwd with `-d`, set through `OPTS` in
  `/etc/sv/iwd/conf` (Valve: a systemd drop-in), and traces with
  `trace-cmd`.
- **Login mode:** from the session's `XDG_CURRENT_DESKTOP` (`gamescope` is
  game mode). The session half belongs to one login session and ends with
  it, so the mode cannot change while it runs. SteamOS watches
  `gamescope-session.service`.
- **Screen reader (`ScreenReader0/1`):** Orca runs as a child of the session
  half, with the variables from `$XDG_RUNTIME_DIR/gamescope-environment`,
  and is restarted when it fails, as `orca.service` is (at most 5 starts in
  10 s).
- **Logout for a mode switch:** the session half asks logind for its own
  login session (`GetSessionByPID`) and ends it (`Session.Terminate`) half a
  second after it replied. SteamOS stops `graphical-session.target`.
- **Calls from games** are refused (`AuthFailed`), as on Valve's main
  branch: a caller whose process descends from Steam's `reaper SteamLaunch`
  counts as a game. SteamOS recognises the game's `app-steam-app…` systemd
  scope, which Io does not have.

What Valve does with systemd user units, Io does in `io-manager-session`
(`/usr/libexec/io`), started in the background by `io-gamemode` and
`io-plasma`:

1. `steamosctl configure-cecd` writes cecd's identity for the TV, before
   cecd starts (`steamos-manager-configure-cecd.service`,
   `Before=cecd.service`); it needs no daemon.
2. cecd through D-Bus activation (`StartServiceByName`).
3. `steamosctl clean-temporary-sessions`
   (`steamos-manager-session-cleanup.service`), which also starts the
   session half.
4. While the default desktop session is still Valve's `plasma.desktop`
   (Plasma without Io's session setup), `io-desktop.desktop` is set
   instead.

`SessionManagement1` is offered only where SDDM's `holo.conf` exists in
`/usr/lib/sddm/sddm.conf.d` (`holo-session-selection` on SteamOS);
`io-session` installs Io's SDDM settings under that name. Access to the root
half is limited to root and `wheel` (Io's D-Bus policy,
`/usr/share/dbus-1/system.d/com.steampowered.SteamOSManager1.conf`).

Steam does not use D-Bus for everything. Some features are enabled by
environment variables alone (the adaptive brightness toggle, fan control,
VRR and tearing switches), and some are helper scripts Steam runs directly
(`jupiter-fan-control`, `steamos-priv-write`); see
[Helper status](Helper-Status).

**Adaptive brightness** is an example: Steam reads the light sensor itself
(`in_illuminance_raw` of the `ltrf216a` under `/sys/bus/iio/devices/`),
gets the calibration gain from `AmbientLightSensor1` (going by the names in
Steam's binaries), and writes the backlight
directly (`steamos-priv-write` hands the file to `wheel` once). No sensor
daemon is involved. The brightness slider moves with the adjustment, as on
SteamOS; this started on Io with Valve's Deck modules in the initramfs
(`steamos-tuning` 1.4). Before, only the backlight followed and the slider
stayed where it was set.

---

## System updates

```
Steam → pkexec steamos-polkit-helpers/steamos-update → /usr/bin/steamos-update → /usr/libexec/io/io-update → xbps-install
D-Bus clients → com.steampowered.Atomupd1 (io-atomupd) ──────────────────────────────┘
```

- **`io-update`** does the work: `check` syncs the repositories and lists
  pending updates (`xbps-install -un`); `apply` updates `xbps` first if it
  is outdated, then runs `xbps-install -yu` and turns its output into
  percentages (downloads by bytes, then the unpack and configure steps per
  package); `applied` tells whether an update waits for a reboot (marker in
  `/run/io-update`, gone after the reboot). One run at a time (`flock`).
  A proxy set through `Atomupd1.EnableHttpProxy` is kept in
  `/run/io-update/proxy` and passed to xbps.
- **`io-atomupd`** (runit service, package of the same name) serves
  `Atomupd1`, atomupd-daemon's update API, on the system bus.
- **`steamos-update`** is Steam's interface on top: exit codes, build id,
  progress lines and *Update completed* as Valve's script prints them.
- Log: `/var/log/io-update.log` (everything xbps printed, with timestamps
  for each run).

---

## Logging

- **Sessions:** `io-start` sends all session output through a FIFO to a
  background `svlogd`, and waits only for the session itself. Logs go to
  `/run/user/1000/io-log-gamemode/` or `io-log-desktop/` — in RAM, rotated at
  5 × 2 MB, gone after a reboot. While Steam's developer mode is on
  (`io-devmode`), the logs go to `~/.local/state/io/` instead and survive
  reboots (20 files).
- **Services:** runit services log through `vlogger` to syslog,
  `socklog-unix` sorts them into `/var/log/socklog/<category>/current`.
- **Kernel:** `nanoklogd` feeds the kernel log into
  `/var/log/socklog/kernel/`.
- `deck` is in the `socklog` group and can read all of it without `sudo`.

---

## Kernel

See [Kernel](Kernel): source, configuration layers, Io's overrides, and
what to do on a kernel update.

---

## Memory

`holo-zram-swap` sets up a zram swap device with half of RAM, zstd and
priority 100, and turns zswap off. Below it, Valve's 1 GiB swap file in
`/home` takes over once zram is full. `earlyoom` waits for that swap to exist
before it starts (its swap threshold would fail otherwise; runit starts
services in parallel).

---

## Audio

Hardware microphone → Valve's filter chain (RNNoise, Valve's microphone
filter) → loopback source, which Steam and games use. Valve's WirePlumber
access rules hide the raw hardware microphone from applications. Speaker
tuning happens in the CS35L41 amplifiers' own DSP.

The speaker gets a loopback too, as on SteamOS 3.8.4 (3.9.2's `steamdeck-dsp`
1.02 creates loopbacks only for sources, see [Deviations](Deviations)):
applications play into
a loopback sink in front of it. The loopback keeps its two channels when the
speaker itself is rebuilt (Steam's *Mono audio* turns it into one channel),
so no application sees the channel count change.

The loopbacks are created at runtime by `io-create-loopback.lua`, Io's port of
Valve's `CreateLoopback()`: it copies the hardware node's channel layout,
priority and card identity (`device.id`, `card.profile.device`). Steam uses
that identity to recognize the built-in devices and shows its own localized
names for them.

The filter chain runs in a second PipeWire instance
(`pipewire -c filter-chain.conf`; on the OLED `filter-chain-galileo.conf`
with Valve's Galileo settings), started per session, with Valve's own
settings: fixed quantum, `mem.mlock-all` within a 100 MB memlock limit, and
a single malloc arena. Volume keys are handled by Steam itself.
Plain ALSA clients reach PipeWire through `alsa-pipewire`, linked in
`/etc/alsa/conf.d/`.

On the Steam Machine (untested) the session points WirePlumber at Valve's
profile for it (`WIREPLUMBER_CONFIG_DIR`, `/usr/share/io/wireplumber-fremont`),
and no filter chain runs.

---

## Drives

```
udev rule 99-steamos-automount  →  io-detach (setsid --fork)  →  block-device-event.sh  →  steamos-automount.sh  →  udisks Mount (as deck)
```

1. **Valve's udev rule** fires when an SD card or USB drive (`mmcblk*`,
   `sd*`) with a filesystem is added or removed, and hands it to
   `io-detach`, which returns at once and runs the rest in the background,
   logging to syslog and `/run/io-detach.log`.
2. **`block-device-event.sh`** leaves out the disk Io runs from (and
   anything already mounted, or any drive when the root disk cannot be
   worked out), waits for udev to finish the event and, at boot, for the
   system bus.
3. **`steamos-automount.sh`** mounts ext4 only, as on SteamOS (other
   filesystems are left alone). It runs `fsck.ext4` first, asks udisks to
   mount the drive for `deck` under `/run/media/deck/<label>`, and makes its
   top directory writable for everyone if `deck` cannot write to it.
4. **Steam** learns about the drive from udisks and lists it in its storage
   settings; a drive without a Steam library gets the offer to format it
   (Valve's `steamos-format-device` helper and `format-device.sh`). With
   `STEAM_ALLOW_DRIVE_ADOPT` and `STEAM_ALLOW_DRIVE_UNMOUNT` set in game
   mode, as in Valve's session, Steam may take over a library on it and
   eject it (not tried yet).

While Io runs from another disk, the internal SSD (with SteamOS, or an
installed Io) is left alone: `90-io-hide-internal-disk.rules` marks it for
udisks as ignored and
belonging to the system (`io-root-disk` tells which disk `/` is on, from
the mount table and sysfs, without asking udev).

---

## Storage expansion

The image is 16 GiB. `io-grow-storage` (also *Expand storage* in the
desktop menu) grows the root partition and its filesystem to the full card,
using only util-linux. It shows what it will do and asks first; it never
runs on its own.
