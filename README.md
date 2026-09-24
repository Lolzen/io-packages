<img src="srcpkgs/io-branding/files/io-logo.svg" alt="Io logo" width="140" align="right">

# Io

A Void Linux rebuild of SteamOS for the Steam Deck (LCD, "Jupiter"). No systemd.

Io is a moon of Jupiter and the most volcanically active world in the solar
system. The sulphur it throws into space forms a plasma ring around Jupiter,
the Io torus. Hence the logo: a ring around a gas giant, with the moon that
creates it sitting on the ring.

> **Status:** [Alpha 1](https://github.com/Lolzen/io-packages/releases/tag/alpha1)
> released, Alpha 2 in progress — see
> [Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones).
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

- Boots straight into Steam's game mode, with an Io boot splash
- Graphics, audio (speakers, headphones, filtered microphone), Wi-Fi,
  Ethernet through a dock, Bluetooth including audio
- Controller, gyro, trackpads, volume keys, brightness, power button,
  suspend and resume
- Steam's performance menu: TDP limit, manual GPU clock; charge limit, fan
  control, Wi-Fi power management, adaptive brightness toggle, *Restart
  Steam* (with Steam's developer mode on) — served by `io-steamos-manager`, Io's own implementation of
  Valve's SteamOS Manager D-Bus service
- Proton games, screenshots
- Switching to the KDE Plasma desktop and back
- Storage expansion to the full card, as an explicit user step
- zram swap, earlyoom and kernel tuning as on SteamOS

Open items and plans are tracked on the
[Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones) page.

## Installation

Io needs an SD card of **at least 32 GB** (the image is 16 GiB). Download the
image from the latest release and write it to the card (replace `sdX` with
the card, all data on it is lost):

```
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

- [Milestones](https://github.com/Lolzen/io-packages/wiki/Milestones) — goals, work lists and final state of each milestone
- [Deviations from SteamOS](https://github.com/Lolzen/io-packages/wiki/Deviations) — where Io differs from SteamOS, and why
- [Architecture](https://github.com/Lolzen/io-packages/wiki/Architecture) — boot, sessions, SteamOS Manager, logging
- [Packages](https://github.com/Lolzen/io-packages/wiki/Packages) — every package, its contents and source
- [Helper status](https://github.com/Lolzen/io-packages/wiki/Helper-Status) — which of Valve's helper scripts are real
- [Building](https://github.com/Lolzen/io-packages/wiki/Building) — building packages and images
- [Pitfalls](https://github.com/Lolzen/io-packages/wiki/Pitfalls) — things that cost real time

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.
