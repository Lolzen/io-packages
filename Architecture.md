# Architecture

How Io works where it cannot simply do what SteamOS does. For the reasons
behind each difference, see [Deviations](Deviations).

---

## Boot

1. **GRUB** from the card's EFI partition. It is installed in removable mode
   without an NVRAM entry, because the card's partition GUIDs change with
   every image build.
2. **Initramfs** (dracut) with `amdgpu` built in for early display, and
   Plymouth, which shows the Io splash from here on.
3. **runit stage 1** runs Void's core services, plus Io's own:
   - `20-dmi-serial-perms.sh` — DMI serial numbers readable by `wheel` only
   - `20-fstab-repair.sh` — comments out invalid SD card lines in fstab
   - `90-io-gamescope-caps.sh` — `CAP_SYS_NICE` file capability on gamescope
4. **runit stage 2** starts the services linked in `/var/service`, among them
   `io-steamos-manager` (root half), `holo-zram-swap`, `earlyoom`,
   `jupiter-fan-control`, `socklog-unix` and `nanoklogd`, and `io-autologin`.
5. **`io-autologin`** waits for the system bus, ends the splash with
   `plymouth quit` and runs `agetty --autologin deck` on tty1. (Not
   `--retain-splash`: that leaves the console in graphics mode, and the
   first-boot network prompt would be invisible.)

---

## Sessions

```
agetty --autologin  →  /etc/profile.d/zz-io-session.sh  →  io-start
                                                            ├─ io-gamemode → gamescope → steam-jupiter
                                                            └─ io-plasma   → startplasma-wayland
```

- **Steam** is started through `steam-jupiter`, Valve's Deck wrapper: it
  keeps Steam on the `steamdeck_stable` branch, adds `-steamdeck -pipewire`,
  and on first start sets Steam up from a preinstalled client. Network setup
  on first start is Steam's own first-run Wi-Fi page.
- **`io-start`** reads the requested session from
  `/run/user/1000/io-session-next` (game mode by default) and starts it under
  its own `dbus-run-session`. All output goes to a log, see *Logging*.
  When the session ends, it also ends PipeWire, so the next session starts
  a fresh PipeWire on its own session bus.
- **`io-gamemode`** reproduces Valve's `gamescope-session`: the same
  environment, gamescope arguments and Steam flags
  (`-steamos3 -steampal -steamdeck -gamepadui`). gamescope starts Steam
  directly as its child. Like Valve's session it limits the portals to the
  gamescope backend (`XDG_DESKTOP_PORTAL_DIR`). It also starts PipeWire, the power button daemon,
  the session half of `io-steamos-manager`, the filter chain's own PipeWire
  instance, and mangoapp for Steam's performance overlay.
- **`io-plasma`** starts KDE Plasma. The session half of
  `io-steamos-manager` starts there through XDG autostart, and so does Steam
  (`steam -silent`, from `steamdeck-kde-presets`), as on SteamOS: it
  provides the on-screen keyboard in the desktop (Steam + X) and keeps hold
  of the controller. Before Plasma starts, `io-plasma` switches Steam's DPI
  scaling off once per user, so Steam draws in real pixels next to Plasma's
  135 %.
- **`io-session.sh`** guards against boot loops: a session that dies within
  15 seconds drops to a shell on tty1 and shows the last 20 log lines. A
  session that ran longer is restarted with `io-start`.

### Switching

- **Game mode → desktop:** Steam calls `SwitchToDesktopMode` on
  `io-steamos-manager`. It writes `desktop` to the state file and ends
  gamescope; `io-session.sh` restarts `io-start`, which now starts Plasma.
- **Desktop → game mode:** the *Return to Gaming Mode* shortcut runs
  `steamos-session-select gamescope`, which calls `SwitchToGameMode` on the
  manager over D-Bus, as on SteamOS. If the manager cannot be reached, it
  falls back to writing the state file and ending kwin itself.

---

## SteamOS Manager

`io-steamos-manager` implements `com.steampowered.SteamOSManager1` in two
halves, like Valve's daemon:

| | Root half | Session half |
|---|---|---|
| Started as | `io-steamos-manager -r`, runit service | `io-steamos-manager`, by `io-gamemode` or XDG autostart |
| Bus | system | session |
| Interfaces | `RootManager` (`SetTdpLimit`, `SetManualGpuClock`, `FanControlState`, ...) | everything Steam talks to (`TdpLimit1`, `GpuPerformanceLevel1`, `FanControl1`, `SessionManagement1`, ...) |
| Does | validates values, writes sysfs, controls runit services | reads sysfs, forwards every write to the root half, reports the value in effect afterwards |

Access to the root half is limited to root and `wheel`
(`/usr/share/dbus-1/system.d/com.steampowered.SteamOSManager1.conf`).

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
priority 100, and turns zswap off. `earlyoom` waits for that swap to exist
before it starts (its swap threshold would fail otherwise; runit starts
services in parallel).

---

## Audio

Hardware microphone → Valve's filter chain (RNNoise, Valve's microphone
filter) → loopback source, which Steam and games use. Valve's WirePlumber
access rules hide the raw hardware microphone from applications. Speaker
tuning happens in the CS35L41 amplifiers' own DSP.

The loopback is created at runtime by `io-create-loopback.lua`, Io's port of
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
