<img src="srcpkgs/io-branding/files/io-logo.svg" alt="Io logo" width="140" align="right">

# Io

A Void Linux rebuild of SteamOS for the Steam Deck. No systemd.

Io is a moon of Jupiter and the most volcanically active world in the solar
system. The sulphur it throws into space forms a plasma ring around Jupiter,
the Io torus. Hence the logo: a ring around a gas giant, with the moon that
creates it sitting on the ring.

> **Status:** [Alpha 1](https://github.com/Lolzen/io-packages/releases/tag/alpha1)
> released. Ships as a disk image (not a live ISO — see the wiki), written
> straight to an SD card with `dd`. Boots directly into game mode, plays
> games, switches to desktop and back.

```
                  ==
        ==================
     ======            ====o=
   =====                  =====
  ====       ~~~~~~~~       ====
 ===      ~~~~~~~~~~~~~~      ===
===      ~~,####~~~,QQQ,~      ===
===     ~~~####~~~QQ'~'QQ~     ===
==      ~~####~~~~QQ,~,QQ~      ==
==      ~#####~~~~~'QQQ'~~      ==
===      ~~~~~~~~~~~~~~~~      ===
===       ~~~~~~~~~~~~~~       ===
 ===         ~~~~~~~~         ===
  ====                      ====
   =====                  =====
     ======            ======
        ==================
```

---

## Documentation

Full documentation lives in the [wiki](https://github.com/Lolzen/io-packages/wiki):

- [Packages](https://github.com/Lolzen/io-packages/wiki/Packages) — what each package contains, upstream sources
- [Architecture](https://github.com/Lolzen/io-packages/wiki/Architecture) — boot, session switching, first-boot steps
- [Pitfalls](https://github.com/Lolzen/io-packages/wiki/Pitfalls) — things that cost real time, documented nowhere else
- [Helper status](https://github.com/Lolzen/io-packages/wiki/Helper-Status) — which of Valve's polkit helpers are real vs. stubbed
- [Building](https://github.com/Lolzen/io-packages/wiki/Building) — how to build and write an image
- [Alpha 1](https://github.com/Lolzen/io-packages/wiki/Alpha-1) — known limitations of the current release

---

## What works

**Boot and hardware**

- Boots on the Steam Deck LCD with correct panel rotation
- Graphics through radv on Van Gogh, gamescope directly on DRM
- Audio through both CS35L41 amplifiers, headphones and internal microphone
  — speaker tuning happens in the amplifier's own hardware DSP (no separate
  software DSP exists for this model), microphone noise suppression and
  tuning run in software via `steamdeck-dsp` (Faust LV2 plugins, ported
  from Valve's own DSP package) and `rnnoise-ladspa` (a from-scratch port
  of werman/noise-suppression-for-voice, since Void's NoiseTorch package
  is GUI-only and ships no system-wide LADSPA plugin)
- ZRAM swap (`holo-zram-swap` + `zramen`) and `earlyoom` both run with
  Valve's own tuning, ported from `holo-zram-swap`/`holo-earlyoom` —
  confirmed live (`zramctl`/`swapon --show` show the right size/algorithm,
  `earlyoom`'s process listing shows Valve's exact arguments)
- WLAN and Ethernet (including dock) through NetworkManager
- Suspend and resume, including wake via the power button
- Fan control through Valve's daemon (idles at 1500 rpm, ramps above 55 °C)
- Bluetooth pairing, device discovery, and audio output/input both work —
  confirmed with a real headset appearing as a PipeWire sink and source
- Gyro works — `hid-steam` exposes it as `Steam Deck Motion Sensors` and Steam
  reads it directly. It is *not* an IIO device, which is why tools looking
  under `/sys/bus/iio/` find nothing

**Game mode**

- Cold boot lands directly in Steam, no login prompt
- Steam runs with `-steamdeck -steamos3`, which enables the SteamOS system menu
- Controller works fully: sticks, trackpads, back buttons, Steam button, overlay
- Volume keys change the volume and the OSD follows
- Brightness slider works (through `steamos-priv-write`)
- Timezone can be set from the client (through Io's `timedatectl` replacement)
- Storage can be grown to fill the card from a desktop shortcut (visible
  terminal, confirm-before-running) instead of a silent first-boot step —
  the old silent `growpart` run blocked all of boot stage 2 with zero
  on-screen indication, and could corrupt the card if powered off mid-resize
- Screenshots work (captured directly by gamescope, not through a desktop
  portal)
- Screen recording / streaming works — `xdg-desktop-portal-gamescope`'s
  `ScreenCast` interface registers and responds correctly (two bugs fixed
  to get there: a `JournalLog::new().unwrap()` that crashed the backend
  outright with no systemd-journald to talk to, and the portal's `.portal`
  file living in an isolated directory that made `xdg-desktop-portal`
  register it in an exclusive mode where nothing else could grant it
  permission — installing it to the standard portals directory fixed both
  at once)
- Power off from the Steam menu works
- Power button suspends immediately on a single press and wakes the device
  — no power drain observed over an overnight suspend
- Proton runs — tested with Magic: The Gathering Arena, including sound
- TDP limit, GPU clock, and performance profile menus work — served by
  `io-steamos-manager`, a from-scratch Python reimplementation of Valve's
  `com.steampowered.SteamOSManager1` DBus interface (Valve's own daemon
  hard-depends on systemd)
- Charge limit works the same way

**Session switching**

- Steam menu → *Switch to Desktop* brings up Plasma within a few seconds —
  as of this reimplementation, Steam calls `io-steamos-manager`'s
  `SwitchToDesktopMode` directly over DBus for this direction, rather than
  going through the flag file
- A desktop shortcut brings you back to game mode (still the flag-file path
  — `io-steamos-manager` doesn't survive the switch to Plasma, see below)
- Plasma has correct rotation, working touchscreen and working trackpads

See [Architecture](https://github.com/Lolzen/io-packages/wiki/Architecture) for how this actually works under the hood.

**Branding**

- `Io` appears in fastfetch and in the Steam system menu

---

## What is open

### Small

- [ ] `jupiter-amp-control` is a stub — the target script is in none of Valve's
      published packages. Audio works without it
- [ ] `steamos-reboot-other` is a stub; it belongs to SteamOS A/B updates,
      which Io does not have
- [ ] Bump revisions consistently; several packages still carry numbers from
      testing
- [ ] **Five small Valve packages ported, not yet device-verified:**
      `steamos-tuning` (sysctl/limits gaming tweaks: TCP MTU probing, faster
      TCP port reuse, scheduler slice, split-lock mitigation disabled,
      raised `vm.max_map_count`, Proton's `nice` ceiling), `steamos-passwd`
      (stdin-driven password-setter wrapper Steam's own UI would call),
      `holo-dmi-rules` (readable DMI serial without root — no Void
      `tmpfiles.d` equivalent, so this runs as a boot-time core-service
      instead), `holo-fstab-repair` (disables invalid `/dev/mmcblk*` fstab
      entries that block UDisks2 — currently a no-op, SD/USB automount
      isn't enabled yet either), `holo-plymouth-themes` (Valve's Jupiter
      boot-splash theme, package builds and installs the theme files —
      not yet wired into dracut/GRUB to actually show during boot)

### Needs work

- [ ] **Ambient light sensor / adaptive brightness — root cause still unclear.**
      `iio-sensor-proxy` now ships and is enabled, the sensor reports live lux
      values, `AlsCalibrationGain` reads correctly at the expected value, and
      the DBus interface was checked line-by-line against Valve's own
      `steamos-manager` source (26.4.1-2) — identical property set, no
      missing method. The toggle in Steam still stays greyed out regardless.
      Not a systems problem as far as we can tell; something Steam checks
      beyond this DBus interface remains unidentified
- [ ] **`io-steamos-manager` dies on session switch.** It runs inside
      `dbus-run-session` in game mode, so it exits with that session — no
      manager is running once Plasma comes up. Fine for now since Plasma has
      no Steam menus to serve, but worth keeping alive across the switch if
      a desktop-side control panel is ever wanted
- [ ] **Power button short-press: possible black-screen edge case.** Backlight
      stays on, Steam UI sounds play, but nothing is drawn — looked like an
      unexecuted suspend request, alongside an unrelated-looking
      `InteractiveAuthorizationRequired` polkit error seen once in Steam's
      log. Never confirmed fixed; worth a dedicated short-press test now that
      elogind/seatd/dbus are solid, separate from the long-press poweroff
      path that's already confirmed working
- [ ] **`CAP_SYS_NICE` for gamescope.** Would silence the performance warning.
      Needs a root-started wrapper that sets an ambient capability and drops
      to `deck` in one step, replacing part of the autologin chain — a PAM
      session hook does not survive the `setuid()` to an unprivileged user,
      and a file capability breaks Steam's overlay injection. Not a
      one-line fix; see Pitfalls
- [ ] **SD/USB automount.** Disabled for now — needs `udisks2` packaged, and
      the boot device itself excluded from the udev rules to avoid a boot-time
      race (see Pitfalls)
- [ ] **Microphone loopback isn't visible in Steam's own audio dropdown.**
      Technically complete and verified — the loopback node exists, has the
      right priority, and produces real audio (`pw-record` against it
      writes a full 3 seconds of a real capture, not silence). Steam's own
      microphone-selection UI still shows nothing, or on manual testing
      shows the raw technical node name instead of a human-readable one.
      Investigated two concrete hypotheses (Steam reading `DeviceModel` for
      hardware identity; the exact property WirePlumber sets on a "hidden"
      loopback) and fixed a real, independent bug in `io-steamos-manager`'s
      `DeviceModel` along the way — neither changed Steam's behavior. Steam's
      actual selection logic here is closed and unverifiable from our side
- [ ] **`CpuBoost1`/`CpuScaling1`/`CpuScheduler1` untested.** `io-steamos-manager`
      exposes these DBus interfaces (found alongside the TDP/GPU-clock ones),
      but nobody has tried them from Steam's own menus yet

### Infrastructure

- [ ] GitHub Actions for automated builds (optional)

### Larger decision

- [ ] **Move to the internal NVMe.** The SD card is too slow for games and has
      caused several timing-related failures during development. It also
      means a warm reboot (`reboot`, including Steam's own restart menu
      entry) boots straight back into the internal SteamOS install instead
      of Io — Io's GRUB is deliberately installed `--removable`, with no
      NVRAM boot entry, since the SD card's partition GUIDs change on every
      rebuild. A cold boot with the card-selection key combo is currently
      the only reliable way back into Io; this goes away entirely once Io
      owns the drive outright
- [ ] **A/B updates, post-1.0.** Not a Beta goal — worth revisiting once Io
      is stable enough to matter. GitHub Releases (or another free hosting
      option) as the update backend, atomic like SteamOS's own A/B scheme.
      See the [Valve package survey](https://github.com/Lolzen/io-packages/wiki/Valve-Package-Survey)
      for what the A/B-dependent Valve packages would bring if this happens

---

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.