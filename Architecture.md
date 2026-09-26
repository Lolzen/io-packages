# Architecture

How Io works where it cannot simply do what SteamOS does. For the reasons
behind each difference, see [Deviations](Deviations).

---

## Boot

1. **GRUB** from the card's EFI partition. It is installed in removable mode
   without an NVRAM entry, because the card's partition GUIDs change with
   every image build.
2. **Initramfs** (dracut) with the `amdgpu` module included for early display, and
   Plymouth, which shows the Io splash from here on.
3. **runit stage 1** runs Void's core services, plus Io's own:
   - `20-dmi-serial-perms.sh` — DMI serial numbers readable by `wheel` only
   - `20-fstab-repair.sh` — comments out invalid SD card lines in fstab
   - `60-io-swapfile.sh` — Valve's 1 GiB swap file in `/home`
   - `61-io-hibernate-guard.sh` — hibernation allowed only with `/` on the
     internal NVMe
   - `70-io-cfs-tunings.sh` — mounts debugfs, applies Valve's scheduler tunings
   - `90-io-gamescope-caps.sh` — `CAP_SYS_NICE` file capability on gamescope
4. **runit stage 2** starts the services linked in `/var/service`, among them
   `io-steamos-manager` (root half), `vpower`, `holo-zram-swap`, `earlyoom`,
   `jupiter-fan-control`, `socklog-unix` and `nanoklogd`,
   `jupiter-firewall`, `steam-web-debug-portforward`, and `io-sddm`. Steam's
   developer mode adds `avahi-daemon` and `steamos-devkit-service`.
5. **`io-sddm`** removes a leftover one-shot login file, ends the splash with
   `plymouth quit --retain-splash` (the screen goes from splash to black to
   game mode, as on SteamOS) and starts SDDM. SDDM logs `deck` in on tty7;
   tty1–6 are plain login consoles.

---

## Sessions

```
SDDM (autologin, Relogin)  →  gamescope-wayland.desktop  →  io-start gamemode  →  io-gamemode → gamescope → steam-jupiter
                           →  io-desktop.desktop         →  io-start desktop   →  io-plasma   → startplasma-wayland
```

SDDM's settings are in `/usr/lib/sddm/sddm.conf.d/10-io.conf`: autologin
for `deck` into game mode, and a fresh login whenever a session ends
(`Relogin=true`), as on SteamOS. The login runs through PAM and elogind, so
each session is a real session on `seat0`; the memlock limit for the filter
chain comes from `/etc/security/limits.d/90-io-memlock.conf`.

- **Steam** is started through `steam-jupiter`, Valve's Deck wrapper: it
  keeps Steam on the `steamdeck_stable` branch, adds `-steamdeck -pipewire`,
  and on first start sets Steam up from a preinstalled client. Network setup
  on first start is Steam's own first-run Wi-Fi page.
- **`io-start`** gets the session from the session file's `Exec` line and
  starts it under its own `dbus-run-session`. All output goes to a log, see
  *Logging*.
  When the session ends, it also ends PipeWire, so the next session starts
  a fresh PipeWire on its own session bus.
- **`io-gamemode`** reproduces Valve's `gamescope-session`: the same
  environment, gamescope arguments and Steam flags
  (`-steamos3 -steampal -steamdeck -gamepadui`). gamescope starts Steam
  directly as its child. Like Valve's session it limits the portals to the
  gamescope backend (`XDG_DESKTOP_PORTAL_DIR`), and passes gamescope's
  statistics pipe (`-T`, `GAMESCOPE_STATS`). It also starts PipeWire, the
  power button daemon, the session half of `io-steamos-manager` (always, one
  per session and bus), the HDMI-CEC daemons, the filter chain's own
  PipeWire instance, and — right before gamescope, once the environment is
  complete — mangoapp for Steam's performance overlay.
- **HDMI-CEC:** `cecd` is started through D-Bus activation
  (`StartServiceByName`), so there is only one way it comes up and the bus
  keeps it to one instance; `cec-audio-control` is started directly and
  creates its socket in `$XDG_RUNTIME_DIR` itself. Both in game mode and in
  Plasma, as SteamOS's user services of the graphical session.
- **Logging out ends the session's processes** (`KillUserProcesses=yes` in
  elogind, as on SteamOS): with SDDM a switch is a logout, and the session's
  bus, its daemons and anything started with `setsid` end with it.
- **`io-plasma`** starts KDE Plasma. The session half of
  `io-steamos-manager` starts there through XDG autostart, and so does Steam
  (`steam -silent`, from `steamdeck-kde-presets`), as on SteamOS: it
  provides the on-screen keyboard in the desktop (Steam + X) and keeps hold
  of the controller. Before Plasma starts, `io-plasma` switches Steam's DPI
  scaling off once per user, so Steam draws in real pixels next to Plasma's
  135 %.
### Switching

As on SteamOS, `SessionManagement1` of `io-steamos-manager` tells SDDM which
session to log in next and ends the running one:

- **Game mode → desktop:** Steam calls `SwitchToDesktopMode`. The root half
  writes the one-shot file `/etc/sddm.conf.d/zzt-steamos-temp-login.conf`,
  gamescope ends, and SDDM logs in with that file: Plasma. The session half
  in the new session removes the file again.
- **Desktop → game mode:** *Return to Gaming Mode* runs
  `steamos-session-select gamescope`, which calls `SwitchToGameMode` over
  D-Bus. Plasma is logged out through its own session manager
  (`org.kde.Shutdown.logout`), which closes every program in order — ending
  kwin alone would not end the session, `kwin_wayland_wrapper` restarts it.
- **Default login mode:** `DefaultLoginMode` writes
  `/etc/sddm.conf.d/zz-steamos-autologin.conf` for a desktop default
  (`steamos-session-select plasma-wayland-persistent`) and removes it for
  game mode.
- **GPU reset:** the udev rule restarts `io-sddm`, as Valve's restarts SDDM:
  any session ends, and SDDM logs in fresh.

---

## SteamOS Manager

`io-steamos-manager` implements `com.steampowered.SteamOSManager1` in two
halves, like Valve's daemon:

| | Root half | Session half |
|---|---|---|
| Started as | `io-steamos-manager -r`, runit service | `io-steamos-manager`, by `io-gamemode` or XDG autostart |
| Bus | system | session |
| Interfaces | `RootManager` (`SetTdpLimit`, `SetManualGpuClock`, `SetLoginSession`, `FanControlState`, ...) | everything Steam talks to (`TdpLimit1`, `GpuPerformanceLevel1`, `FanControl1`, `SessionManagement1`, `LowPowerMode1`, `Audio1`, `HdmiCec1`, `ScreenReader0/1`, ...) |
| Does | validates values, writes sysfs, controls runit services | reads sysfs, forwards every write to the root half, reports the value in effect afterwards |

Access to the root half is limited to root and `wheel`
(`/usr/share/dbus-1/system.d/com.steampowered.SteamOSManager1.conf`).

Some session-half interfaces drive other programs, as steamos-manager does:

- **`ScreenReader0/1`:** starts and stops Orca (detached, with the running
  Steam's display settings), writes Orca's `user-settings.conf` and has
  Orca reload it (`SIGUSR1`), lists voices from speech-dispatcher, and
  presses Orca's shortcuts on a virtual keyboard named `steamos-manager`
  (`/dev/uinput`, group `input`)
- **`HdmiCec1`:** writes `~/.config/cecd/config.d/00-` and
  `99-steamos-manager.toml`, then sends cecd `SIGHUP`
- **`Audio1`:** WirePlumber's `node.features.audio.mono`, saved
- **`LowPowerMode1`:** hands out the write end of a pipe; while any is
  open, the TDP is 6 W

Steam does not use D-Bus for everything. Some features are enabled by
environment variables alone (the adaptive brightness toggle, fan control,
VRR and tearing switches), and some are helper scripts Steam runs directly
(`jupiter-fan-control`, `steamos-priv-write`); see
[Helper status](Helper-Status).

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

The speaker gets a loopback too, as on SteamOS 3.8.4: applications play into
a loopback sink in front of it. The loopback keeps its two channels when the
speaker itself is rebuilt (Steam's *Mono audio* turns it into one channel),
so no application sees the channel count change.

The loopbacks are created at runtime by `io-create-loopback.lua`, Io's port of
Valve's `CreateLoopback()`: it copies the hardware node's channel layout,
priority and card identity (`device.id`, `card.profile.device`). Steam uses
that identity to recognize the built-in devices and shows its own localized
names for them.

The filter chain runs in a second PipeWire instance
(`pipewire -c filter-chain.conf`), started per session, with Valve's own
settings: fixed quantum, `mem.mlock-all` within a 100 MB memlock limit, and
a single malloc arena. Volume keys are handled by Steam itself.
Plain ALSA clients reach PipeWire through `alsa-pipewire`, linked in
`/etc/alsa/conf.d/`.

---

## Storage expansion

The image is 16 GiB. `io-grow-storage` (also *Expand storage* in the
desktop menu) grows the root partition and its filesystem to the full card,
using only util-linux. It shows what it will do and asks first; it never
runs on its own.
