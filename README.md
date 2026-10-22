<img src="srcpkgs/io-branding/files/io-logo.svg" alt="Io logo" width="140" align="right">

# Io

A Void Linux rebuild of SteamOS for the Steam Deck (LCD, "Jupiter"). No systemd.

Io is a moon of Jupiter and the most volcanically active world in the solar
system. The sulphur it throws into space forms a plasma ring around Jupiter,
the Io torus. Hence the logo: a ring around a gas giant, with the moon that
creates it sitting on the ring.

> **Status:** [Alpha 7](https://github.com/Lolzen/io-packages/releases/tag/alpha7)
> released (Valve's patches, restart into Io) — see
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
behaviour is checked against a reference capture of real SteamOS (now
3.9.2) on the same device, not against assumptions. Where Io deliberately differs, the
reason is documented in
[Deviations from SteamOS](https://github.com/Lolzen/io-packages/wiki/Deviations).

## What works

- Boots straight into Steam's game mode, with an Io boot splash; login and
  switching to the desktop and back through SDDM, as on SteamOS
- Steam as on SteamOS: Valve's Deck packaging, on the Deck's update branch,
  preinstalled — the first start needs no download
- System updates from Steam (Settings → System), with xbps behind it
- Graphics, Wi-Fi (backend switchable from Steam, as on SteamOS), Ethernet
  through a dock, Bluetooth including audio
- Audio as on SteamOS: speakers, headphones, filtered microphone, with
  Steam's own translated device names
- Controller, gyro, trackpads, volume keys (handled by Steam), brightness,
  status LED, power button, suspend and resume
- Steam's performance menu: TDP limit, manual GPU clock, charge limit, fan
  control, Wi-Fi power management, adaptive brightness, performance overlay;
  *Restart Steam* with Steam's developer mode on. Served by Valve's
  SteamOS Manager, with the runit support Io adds
  ([Lolzen/steamos-manager](https://github.com/Lolzen/steamos-manager),
  branch `runit`)
- Battery: controlled shutdown through Steam when the battery runs empty
  (Valve's vpower)
- Proton games, gamemode, screenshots, screen recording
- Steam's keyboard in game mode, including Chinese, Japanese and Korean
  input
- KDE Plasma desktop with Valve's Deck defaults: Steam runs in the
  background, Steam's on-screen keyboard (Steam + X), Plasma's own
  (`plasma-keyboard`, switched on in System Settings), *Return to Gaming
  Mode*; the brightness set in game mode carries over
- Storage expansion to the full card, as an explicit user step
- SD cards and USB drives mount on their own (ext4, as on SteamOS) and are
  formatted from Steam; while Io runs from a card, the internal SSD stays
  hidden; storage trim from SteamOS Manager
- Valve's firmware updaters (BIOS, controller, dock) with Steam's checks,
  and Valve's thumbstick and trigger calibration tools
- zram swap, swap file, earlyoom, kernel and scheduler tuning as on
  SteamOS; the LAVD CPU scheduler for tools that switch it
- Steam's system report, saved from Steam's own UI
- Accessibility: Steam's screen reader and mono audio
- HDMI-CEC with Steam's switches, a firewall with Valve's rules (and
  Plasma's firewall page), and the SteamOS Devkit Client

Not yet released: installing to the internal SSD (the recovery stick does
it). A real BIOS or controller update is untested. Built and tested on the
Steam Deck LCD; Valve's packages for the OLED, the Steam Machine and Valve's
own dock are in place, but need someone with the hardware to test.

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
- [Kernel](https://github.com/Lolzen/io-packages/wiki/Kernel) — source, configuration layers, what to do on a kernel update
- [Helper status](https://github.com/Lolzen/io-packages/wiki/Helper-Status) — which of Valve's helper scripts are real
- [Building](https://github.com/Lolzen/io-packages/wiki/Building) — building packages and images, release workflow
- [Pitfalls](https://github.com/Lolzen/io-packages/wiki/Pitfalls) — things that cost real time
- [SteamOS packages](https://github.com/Lolzen/io-packages/wiki/Valve-Package-Survey) — every SteamOS-specific package, and what Io has in its place

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.