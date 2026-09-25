<img src="srcpkgs/io-branding/files/io-logo.svg" alt="Io logo" width="140" align="right">

# Io

A Void Linux rebuild of SteamOS for the Steam Deck (LCD, "Jupiter"). No systemd.

Io is a moon of Jupiter and the most volcanically active world in the solar
system. The sulphur it throws into space forms a plasma ring around Jupiter,
the Io torus. Hence the logo: a ring around a gas giant, with the moon that
creates it sitting on the ring.

> **Status:** [Alpha 4](https://github.com/Lolzen/io-packages/releases/tag/alpha4)
> released, Alpha 5 (storage: SD cards and USB drives) next — see
> [Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones) and the
> [Changelog](https://github.com/Lolzen/io-packages/wiki/Changelog).
> Io ships as a disk image, written straight to an SD card with `dd`. It
> boots into Steam's game mode, plays games, and switches to the KDE Plasma
> desktop and back.

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

## Goal

Behave like SteamOS wherever the hardware and the Steam client are
concerned, on top of Void Linux with runit instead of systemd. Io's
behaviour is checked against a reference capture of real SteamOS on the
same device, not against assumptions. Where Io deliberately differs, the
reason is documented in
[Deviations from SteamOS](https://github.com/Lolzen/io-packages/wiki/Deviations).

## What works

- Boots straight into Steam's game mode, with an Io boot splash; login and
  switching to the desktop and back through SDDM, as on SteamOS
- Steam as on SteamOS: Valve's Deck packaging, on the Deck's update branch,
  preinstalled — the first start needs no download
- Graphics, Wi-Fi (backend switchable from Steam, as on SteamOS), Ethernet
  through a dock, Bluetooth including audio
- Audio as on SteamOS: speakers, headphones, filtered microphone, with
  Steam's own translated device names
- Controller, gyro, trackpads, volume keys (handled by Steam), brightness,
  status LED, power button, suspend and resume
- Steam's performance menu: TDP limit, manual GPU clock, charge limit, fan
  control, Wi-Fi power management, adaptive brightness, performance overlay;
  *Restart Steam* with Steam's developer mode on. Served by
  `io-steamos-manager`, Io's own implementation of Valve's SteamOS Manager
- Battery: controlled shutdown through Steam when the battery runs empty
  (Valve's vpower)
- Proton games, gamemode, screenshots, screen recording (with gamescope
  3.16.22 or later, see below)
- KDE Plasma desktop with Valve's Deck defaults: Steam runs in the
  background, Steam's on-screen keyboard (Steam + X), *Return to Gaming
  Mode*
- Storage expansion to the full card, as an explicit user step
- zram swap, swap file, earlyoom, kernel and scheduler tuning as on
  SteamOS; the LAVD CPU scheduler for tools that switch it
- Steam's system report, saved from Steam's own UI

Not yet: automatic mounting of SD cards and USB drives (Alpha 5),
installing to the internal SSD. Screen recording needs gamescope 3.16.22 or
later; Void still ships 3.16.20 (an update is submitted).

Open items and plans are tracked on the
[Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones) page.

## Installation

Io needs an SD card of **at least 32 GB** (the image is 16 GiB). Download all
`io.img.xz.part*` files and `io.img.xz.sha256` from the
[latest release](https://github.com/Lolzen/io-packages/releases/latest),
join and check them, then write the image to the card (replace `sdX` with
the card, all data on it is lost):

```
cat io.img.xz.part* > io.img.xz
sha256sum -c io.img.xz.sha256
xz -d io.img.xz
sudo dd if=io.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot the Deck from the card (hold Volume Down, press Power, pick the card).

**The first boot:**

- goes straight into Steam: the client comes preinstalled, as on SteamOS
- Steam's own first-run setup connects to Wi-Fi, using the Deck's controls
  — no keyboard, no Ethernet needed
- takes a little longer than later boots while Steam unpacks itself

Then run *Expand storage* from the desktop menu, or `io-grow-storage` in a
terminal, to use the whole card.

Default user and password: `deck` / `deck`. **The SSH server is enabled
during the test phase** — change the password with `passwd` before using
Io on a network you do not trust.

## Documentation

Everything else lives in the [wiki](https://github.com/Lolzen/io-packages/wiki):

- [Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones) — what is open, and where it is headed
- [Changelog](https://github.com/Lolzen/io-packages/wiki/Changelog) — what each release brought
- [Deviations from SteamOS](https://github.com/Lolzen/io-packages/wiki/Deviations) — where Io differs from SteamOS, and why
- [Architecture](https://github.com/Lolzen/io-packages/wiki/Architecture) — boot, sessions, SteamOS Manager, logging
- [Packages](https://github.com/Lolzen/io-packages/wiki/Packages) — every package, its contents and source
- [Helper status](https://github.com/Lolzen/io-packages/wiki/Helper-Status) — which of Valve's helper scripts are real
- [Building](https://github.com/Lolzen/io-packages/wiki/Building) — building packages and images, release workflow
- [Pitfalls](https://github.com/Lolzen/io-packages/wiki/Pitfalls) — things that cost real time
- [Valve package survey](https://github.com/Lolzen/io-packages/wiki/Valve-Package-Survey) — Valve's packages, triaged for Io

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.