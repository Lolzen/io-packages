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
- WLAN and Ethernet (including dock) through NetworkManager
- Suspend and resume, including wake via the power button
- Fan control through Valve's daemon (idles at 1500 rpm, ramps above 55 °C)
- Bluetooth pairing and device discovery (audio output over Bluetooth does not
  yet work — see Pitfalls)
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
- Power off from the Steam menu works
- Power button suspends and wakes the device
- Proton runs — tested with Magic: The Gathering Arena, including sound

**Session switching**

- Steam menu → *Switch to Desktop* brings up Plasma within a few seconds
- A desktop shortcut brings you back to game mode
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

### Needs work

- [ ] **TDP and charge limit.** The menu entries exist under `-steamos3` but do
      nothing. This needs `steamos-manager`, which hard-depends on systemd,
      manages systemd units as part of its actual logic, and ships three user
      units bound to `gamescope-session.service`. Porting it means forking its
      system interface, not just repackaging it
- [ ] **Screen capture.** `xdg-desktop-portal-wlr` fails in game mode, which
      affects screenshots and streaming. Valve ships
      `xdg-desktop-portal-gamescope` and `xdg-desktop-portal-holo` — worth a
      look before writing anything
- [ ] **Bluetooth audio.** PipeWire's BlueZ SPA plugin is missing or broken;
      pairing works but no audio route exists yet
- [ ] **`CAP_SYS_NICE` for gamescope.** Would silence the performance warning.
      Needs a root-started wrapper that sets an ambient capability and drops
      to `deck` in one step, replacing part of the autologin chain — a PAM
      session hook does not survive the `setuid()` to an unprivileged user,
      and a file capability breaks Steam's overlay injection. Not a
      one-line fix; see Pitfalls
- [ ] **SD/USB automount.** Disabled for now — needs `udisks2` packaged, and
      the boot device itself excluded from the udev rules to avoid a boot-time
      race (see Pitfalls)
- [ ] **Visible, opt-in partition growth.** Currently a silent first-boot
      `growpart` run; planned replacement is a desktop shortcut the user
      triggers manually, in a visible terminal, like the game-mode switch

### Infrastructure

- [ ] GitHub Actions for automated builds (optional)

### Larger decision

- [ ] **Move to the internal NVMe.** The SD card is too slow for games and has
      caused several timing-related failures during development.

---

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.