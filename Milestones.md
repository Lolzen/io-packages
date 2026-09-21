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

### Open

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
- [ ] Screen recording: check whether the gamescope portal is still found;
      SteamOS sets `XDG_DESKTOP_PORTAL_DIR` for the game mode session
- [ ] Boot splash: wire `holo-plymouth-themes` into dracut and GRUB
- [ ] Clean-up: remove `inputplumber` (not buildable, disabled on the Deck
      even on SteamOS), `docs/handler.sh.io` (acpid leftover), the unused
      files in `io-branding`, and review the helper scripts from before the
      disk image (`mksd.sh`, `mkiso.sh`, `link.sh`, `build.sh`, `pkglist.sh`,
      `mountsd.sh`, the second `mklogo.py`)
- [x] `io-selftest.sh`: checks a running system against the Alpha 2 state
      (60 checks; passes on the development card)

### Release acceptance (last step before tagging Alpha 2)

- [ ] Build a fresh image with `mkimg.sh`, write it to a spare card, boot,
      grow storage, run `io-selftest.sh` - must match the development card
- [ ] Write the final state below
- [ ] Test without `seatd` (elogind only)
- [ ] Decide the Wi-Fi backend: SteamOS uses iwd, Io uses wpa_supplicant
- [ ] Stub helpers worth implementing: SSH toggle, SD card formatting
- [ ] Documentation overhaul (README and wiki, English throughout)

### Deferred to after Alpha 2

- Regular review of boot logs for improvements and regressions
- `steamos-powerbuttond` 4.2 (Io ships 3.1)
- `deck-firmware-cirrus`: check whether Void's `linux-firmware` ships these
  files by now
- `io-volumed`: test whether Steam's own volume handler replaces it
- Audio fine-tuning: localized device names, speaker and headphone loopbacks
  as on SteamOS
- Kernel package naming (`linux-neptune` meta package pointing to the
  current version)
- Plasma polish
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

- **Switch to SDDM for login and session switching**, as SteamOS does.
  Would replace the `agetty → io-session.sh → io-start` chain. A deliberate
  decision for its own milestone, not a side task.
  If it happens, the GPU reset rule goes back to Valve's behaviour with
  `sv restart sddm`: revert the Alpha 2 commit that changed
  `80-gpu-reset.rules` (`76ad031`) and replace `systemctl` with
  `sv`.