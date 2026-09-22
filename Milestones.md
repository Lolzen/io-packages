# Milestones

Each milestone has a goal, a work list that is kept current while the work
happens, and — once it is released — a frozen final state. The final state
is written once and not edited afterwards; later corrections go into the
next milestone.

---

## Alpha 1 — released

**Goal:** a bootable Void Linux image for the Steam Deck LCD that lands in
Steam's game mode, plays games, and can switch to the desktop and back.

**Release:** [alpha1](https://github.com/Lolzen/io-packages/releases/tag/alpha1)

**Final state:** see [Alpha 1](Alpha-1) for the known limitations at release
time. Package and service lists of that image:
[pkglist-milestone1.txt](https://github.com/Lolzen/io-packages/blob/main/docs/pkglist-milestone1.txt),
[services-milestone1.txt](https://github.com/Lolzen/io-packages/blob/main/docs/services-milestone1.txt).

---

## Alpha 2 — in progress

**Goal:** match real SteamOS behaviour wherever Io can, based on a reference
capture of SteamOS 3.8.4 on the same hardware instead of assumptions, and
ship an image that is reproducible from the repository alone.

### Method

Before any change, a full reference capture was taken on real SteamOS:
process environments and capabilities, every SteamOS Manager D-Bus value on
both buses, sysfs values, systemd units, configuration files, and a guided
D-Bus trace of 18 actions in game mode (TDP, GPU clock, brightness, session
switch, suspend, ...). Io's behaviour is checked against that capture, not
against documentation or memory.

### Done

- **Game mode session rebuilt after Valve's `gamescope-session`:** same
  Steam flags (`-steamos3 -steampal -steamdeck -gamepadui`), same gamescope
  arguments, same environment. This alone brought back *Restart Steam*, the
  adaptive brightness toggle and the fan control toggle — all three are
  gated by launch flags or environment variables, not by D-Bus
- **`io-steamos-manager` 0.3.0:** split into a root half (system bus, runit
  service) and a session half, like Valve's `steamos-manager`. Values match
  the capture (TDP 3–15 W, GPU power profiles, desktop session name).
  Setters report the value actually in effect. Replaces `io-priv-exec` and
  per-change `pkexec`
- **Fan control and Wi-Fi power management helpers** are real instead of
  stubs; Steam calls these helpers directly, not over D-Bus
- **gamescope runs with `CAP_SYS_NICE`**, set as a file capability exactly as
  on SteamOS; RTKit added (Steam and PipeWire request realtime threads
  through it)
- **Memory handling as on SteamOS:** own zram service (50 % RAM, zstd,
  priority 100), zswap off, earlyoom with Valve's full argument set and
  ordered after swap, `kernel.pid_max` raised. A nice limit and PAM patch
  that SteamOS does not have were removed
- **Logging:** session output goes to a rotating log instead of tty1, kept
  across reboots when Steam's developer mode is on; `socklog-void` as syslog
  so runit services no longer log into nothing. Found and fixed a polkitd
  instance restarting every second
- **polkit started through D-Bus only**, as on SteamOS
- **Microphone visible in Steam:** the loopback source needed a fixed format
  (2 channels, FL/FR), which Valve's own WirePlumber patch sets
- **Storage expansion** as an explicit user step (menu entry or
  `io-grow-storage`), using only util-linux; `cloud-guest-utils` and its
  resize-at-boot service are gone
- **KDE Plasma** is part of `io-desktop`, with the application set of
  SteamOS and OctoXBPS instead of Discover/Flatpak
- **`publish.sh`** uploads only new files and cleans stale release assets

### Work list

- [x] `io-desktop`: add every package the running system uses
      (`steamdeck-dsp`, `holo-zram-swap`, `holo-earlyoom`, `steamos-tuning`,
      `holo-dmi-rules`, `holo-fstab-repair`, `steamos-passwd`) and switch the
      kernel to `linux-neptune-72`
- [x] udisks2 is now installed (pulled in by Plasma): checked -
      `deck-hw-support`'s automount and SD rescan rules are fully commented
      out, nothing fires at boot. Automount itself moves to after Alpha 2
- [x] GPU reset udev rule: Valve restarts SDDM after a GPU crash; Io has no
      display manager, so the rule now ends gamescope and `io-session.sh`
      starts a fresh session (commit `76ad031`)
- [x] Portals isolated in game mode as on SteamOS (`XDG_DESKTOP_PORTAL_DIR`
      in the bus activation environment, `gamescope-portals.conf`); the KDE
      and GTK portals Plasma installs no longer start and crash there
- [x] VA-API: `mesa-vaapi` and `mesa-vaapi-32bit` added; Void ships the
      driver separately, SteamOS has it in Mesa
- [ ] Screen recording: moved to after Alpha 2, see below
- [x] Boot splash: Io-branded Plymouth theme (proof of concept), Plymouth in
      the initramfs, handed over to the session by `io-autologin`.
      `holo-plymouth-themes` turned out to be the controller-update splash,
      not the boot splash, and was dropped
- [x] Clean-up: `inputplumber`, `holo-plymouth-themes`, `docs/handler.sh.io`,
      `link.sh`, `pkglist.sh`, `mksd.sh` removed; `build.sh` now copies
      packages into `void-packages` and can publish in the same step;
      unused files in `io-branding` removed
- [x] English throughout: all on-device messages, desktop entries, comments
- [x] `io-netcheck` moved into `io-session`: `mkimg.sh` had patched it into a
      file owned by `io-session`, so it vanished on the first update
- [x] `io-selftest.sh`: checks a running system against the Alpha 2 state
      (60 checks; passes on the development card)
- [x] Test without `seatd`: libseat uses elogind, game mode, session
      switching and suspend work; seatd removed
- [x] Session switching hung after the logging change: a PipeWire process
      outliving the session kept the log pipe open. `io-start` now logs
      through a FIFO and starts a fresh PipeWire per session
- [x] SSH sessions are closed before the network goes down at shutdown
- [x] SSH toggle in Steam's developer settings: `steamos-enable-sshd` is real
      (links the runit service). The image keeps SSH enabled during the test
      phase
- [x] Documentation overhaul: README and wiki rewritten in English, new
      [Deviations](Deviations) page

### Release acceptance (last step before tagging Alpha 2)

- [ ] Build a fresh image with `mkimg.sh`, write it to a spare card, boot,
      grow storage, run `io-selftest.sh` - must match the development card
- [ ] Write the final state below

### Deferred to after Alpha 2

- Regular review of boot logs for improvements and regressions
- **Screen recording** produces clips without video. Steam creates its audio
  encoder but never a video encoder, and gamescope's PipeWire stream arrives
  as shared memory (`dmabuf: 0`). VA-API works for Steam's 64-bit runtime
  since `mesa-vaapi`. Next step: the same recording on SteamOS, comparing
  `streaming_log.txt` (`dmabuf`, encoder lines)
- The session has no `LANG`; SteamOS sets it (Qt falls back to `C.UTF-8`)
- Wi-Fi backend: live test of iwd (SteamOS's default), then decide; if iwd,
  implement `SetWifiBackend` for the developer menu switch
- SD card formatting from Steam (`steamos-format-sdcard` stub); needs
  automount first
- `steamos-powerbuttond` 4.2 (Io ships 3.1)
- `deck-firmware-cirrus`: check whether Void's `linux-firmware` ships these
  files by now
- `io-volumed`: test whether Steam's own volume handler replaces it
- Audio fine-tuning: localized device names, speaker and headphone loopbacks
  as on SteamOS
- Kernel package naming (`linux-neptune` meta package pointing to the
  current version)
- Plasma polish
- Branding: the proof-of-concept splash is a static logo; a designed splash,
  and filling the black gap while Steam loads inside gamescope (6–10 s from
  the SD card), are open. Also check Io packages for remaining Valve
  graphics
- SD/USB automount (needs `systemd-run` replaced by `setsid --fork` in the
  rules and the boot device excluded); best done together with the move to
  the internal NVMe
- Kernel command line: compare with SteamOS's `amdgpu` options
  (`lockup_timeout`, `sched_hw_submission`, `dcdebugmask`, `ttm.pages_min`)
- Live ISO: retry once void-mklive handles dracut 112's live-boot changes
  (the reason Io ships as a disk image)

### Final state

*Written at release.*

---

## Next milestone

*Goals follow once Alpha 2 is released.*

### Candidates

- **For 1.0:** SSH off in images as on SteamOS (drop `sshd` from `SERVICES`
  in `mkimg.sh`), and a way to replace the default password, e.g. a prompt on
  first boot

- **Switch to SDDM for login and session switching**, as SteamOS does.
  Would replace the `agetty → io-session.sh → io-start` chain. A deliberate
  decision for its own milestone, not a side task.
  If it happens, the GPU reset rule goes back to Valve's behaviour with
  `sv restart sddm`: revert the Alpha 2 commit that changed
  `80-gpu-reset.rules` (`76ad031`) and replace `systemctl` with
  `sv`.
