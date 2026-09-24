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

## Alpha 2 — released

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
- [→] Screen recording: moved to after Alpha 2, see below
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

### Release acceptance

- [x] Fresh image built, written to a spare card, booted, storage grown,
      `io-selftest.sh` passes. Found and fixed on the way: the first-boot
      network prompt was invisible (`--retain-splash`), the image had grown
      past 12 GB (now 16 GiB, 32 GB card needed)
- [x] Final state written below

### Deferred to after Alpha 2

- Regular review of boot logs for improvements and regressions
- **First boot without a keyboard:** network setup usable with the Deck's
  own controls; then reconsider `--retain-splash`. A live ISO with an
  installer would solve this differently
- **Broken first Steam start:** detect an interrupted bootstrap (empty
  `steam.sh`) and redo it
- **Screen recording** produces clips without video. Steam creates its audio
  encoder but never a video encoder, and gamescope's PipeWire stream arrives
  as shared memory (`dmabuf: 0`). VA-API works for Steam's 64-bit runtime
  since `mesa-vaapi`. On SteamOS the same stream is also shared memory
  (`dmabuf: 0`) and Steam's runtime VA-API check fails there as well, so
  neither is the cause. The difference: SteamOS logs "Trying to create an
  encoder for recording" right after the format negotiation, Io never does
  — the frames apparently never arrive. SteamOS reference while recording:
  `gamescope:capture_1 → steam:input_1` active, both nodes running, Steam's
  stream with `target.object = gamescope`, `media.role = Camera`. Next step:
  the same dump on Io during a recording (`rec-dump.sh`)
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

Released as [alpha2](https://github.com/Lolzen/io-packages/releases/tag/alpha2).

- Boots into game mode with an Io splash; game mode session reproduces
  Valve's `gamescope-session`; switching to Plasma and back works
- `io-steamos-manager` with root and session half; TDP (3–15 W), GPU clock,
  charge limit, fan control, Wi-Fi power management verified against sysfs
- Audio: speakers, headphones, filtered microphone (visible in Steam),
  Bluetooth audio; fresh PipeWire per session
- Memory, logging, polkit, CAP_SYS_NICE, RTKit and portals as on SteamOS
  (see [Deviations](Deviations) for what differs)
- Image reproducible from the repository alone: `mkimg.sh` output passes
  `io-selftest.sh` on a fresh card
- Known limitations: screen recording without video; first-boot Wi-Fi setup
  needs a keyboard; SSH enabled with the default password; see the list
  above for everything moved to the next milestone

---

## Alpha 3 — Parity & Quality of Life — released

**Goal:** close the many small gaps to SteamOS that have piled up, and make
everyday use smoother. A few larger items, mostly small ones — together
they are about stability, consistency and user experience.

Order: quick wins first, then a triage of the unported Valve packages (one
decision per package), screen recording alongside since its path is clear,
the larger items and the interface last.

### Done

- [x] Clean-up: dropped the 6.15.8 fallback kernel `linux-neptune`; removed
      the unused `config-io` from `linux-neptune-72` (it was never merged,
      `CONFIG_HID_HAPTIC` was not in the 7.2 build), the never-enabled runit
      service in `steamos-powerbuttond`, a second unused `timedatectl` in
      `deck-hw-support`, and `bootstrap` plus redundant dependencies in
      `io-base`

- [x] Correction to Alpha 2: *Restart Steam* in the power menu also needs
      Steam's developer mode, on SteamOS too; `-gamepadui` alone is not
      enough. A fresh Steam profile has developer mode off

### Quick wins

- [x] `LANG` in the session: no locale was ever generated (all of
      `libc-locales` commented out), and the session started before
      `profile.d/locale.sh` ran. `mkimg.sh` now enables the locales SteamOS
      ships (`holo-glibc-locales`, every Steam language) and writes only
      `LANG` to `locale.conf`; the session profile script is now
      `zz-io-session.sh` and runs last
- [x] Kernel command line as on SteamOS: `amdgpu` lockup timeouts,
      `sched_hw_submission`, `dcdebugmask`, `ttm.pages_min` instead of the
      deprecated `amdgpu.gttsize` (whose GTT/TTM mismatch the kernel warned
      about), `log_buf_len=4M`, `rd.*` skips. GTT now 8192M, as on SteamOS
- [x] Broken first Steam start: solved at the root by `steam-jupiter` (see
      *Larger items*) — Steam no longer downloads itself on first start
- [x] Steam's own volume handler works (5 % steps, OSD, also in games):
      `STEAM_ENABLE_VOLUME_HANDLER` is set, `io-volumed` dropped
- [ ] `steamos-powerbuttond` 3.1 → 4.2, from Valve's mirror *(→ Alpha 4)*
- [ ] Kernel metapackage `linux-neptune` pointing to the current kernel *(→ Alpha 4)*
- [x] `deck-firmware-cirrus` dropped: Void's main `linux-firmware` package
      (30 MB) ships the Deck's CS35L41 files, newer and including the
      device-specific `vlv1776` firmware the amplifiers now load
- [x] Found on the way: ALSA's default device was not routed through
      PipeWire — Void leaves the `alsa-pipewire` links to the admin, so
      ALSA-only programs could not play at all. `io-base` now ships them

### Stub helpers: one decision each

| Helper | Direction |
|---|---|
| `steamos-format-sdcard`, `steamos-format-device` | Port with automount (Alpha 4) |
| `jupiter-biosupdate`, `jupiter-dock-updater` | Likely stay stubs: firmware updates are risky and SteamOS on the same device handles them |
| `steamos-devkit-mode` | Only useful with Valve's devkit service; niche |
| `jupiter-amp-control` | Target script exists in none of Valve's packages |
| `steamos-update`, `-select-branch`, `-reboot-other`, `-factory-reset-config` | Tied to A/B updates; only with an own update mechanism |
| `steamos-restart-sddm` | Only with SDDM |

- [ ] Confirm each decision and record it on [Helper status](Helper-Status) *(→ Alpha 4)*

### Unported Valve packages: triage

Installed on SteamOS 3.8.4, missing on Io. Each gets a decision: port,
integrate into an existing Io package, or drop with a reason.

- [x] `mangohud` / mangoapp: Steam's performance overlay works. Io starts
      mangoapp per session (Valve uses a service with `Restart=always`) and
      provides `MANGOHUD_CONFIGFILE`, written as `no_display` first as Valve
      does; Steam sets the `STEAM_*MANGOAPP*` variables itself
- [x] `gamemode`: Void's package ships everything (polkit rule and actions,
      limits file, D-Bus activation); `deck` joins the `gamemode` group. The
      daemon starts on demand through D-Bus instead of running always
- [x] `steam-jupiter-stable`: ported as `steam-jupiter`, see *Larger items*
- [x] `vpower` (found through `holo-upower-config`): Valve's battery daemon.
      Writes battery metrics for Steam to `/run/vpower/` and asks Steam to
      shut down at 0.5 %, forcing `poweroff` after 10 s. Io patches its
      hardcoded `hwmon3` (the index differs with Io's kernel, so the charge
      limit was not found)
- [x] `holo-upower-config`: turns UPower's own critical action off, since
      vpower handles it; ships only together with vpower. Valve's file says
      `AllowRiskyCriticalPowerAction=yes`, which UPower rejects (booleans are
      `true`/`false`) — Io fixes it, otherwise the file has no effect
- [x] `jupiter-legacy-support`: a collection of leftovers; nothing needed
      now. `KillUserProcesses=True` has no effect on Io (session switches do
      not end the login). `steam-web-debug-portforward` (CEF debugging in
      developer mode) is a possible later addition
- [x] `steamos-alias` (found through `jupiter-legacy-support`): not needed.
      Valve's changes from 20250728.1 to 20260807.1 are almost all the
      rename to `holo-*`; SteamOS 3.8.4 still runs the `steamos-*` names.
      `deck-hw-support` is now 20260807.1 with Io keeping the old names and
      taking the real changes: a sturdier `jupiter-check-support`,
      restructured GPU reset rules, and Valve's cursor theme (new in Io)
- [x] `steam-im-modules`: built from Valve's source; Steam's on-screen
      keyboard as input method in GTK 3/4 and Qt 5 apps (not Qt 6, so not
      in Plasma's own apps); `GTK_IM_MODULE`/`QT_IM_MODULE` set in game mode
- [x] `steamdeck-kde-presets` 3.9.4: Valve's Plasma defaults. Most
      important: Steam autostarts in the desktop. That brings Steam's
      on-screen keyboard (Steam + X) to the desktop, and ends the periodic
      desktop freezes — without Steam holding the controller, Plasma's game
      controller page reopened it again and again, and each time the kernel
      dropped the trackpad pointer. Also: Vapor look (Deck variant), power,
      screen locker, Baloo, KWallet, language synced with Steam, IBus, Valve's
      *Return to Gaming Mode* (replaces Io's own)
- [x] Steam in the desktop draws in real pixels, as on SteamOS: `io-plasma`
      sets `DPIScaling` to 0 once per user. Plasma keeps its 135 %; with DPI
      scaling on, Steam's keyboard was wider than the screen
- [ ] `holo-sudo` — sudo defaults *(→ Alpha 4)*
- [ ] `steamos-networking-tools` *(→ Alpha 4)*
- [ ] `steamos-systemreport` — system report for bug reports *(→ Alpha 4)*
- [ ] `jupiter-firewall` *(→ Alpha 4)*
- [ ] `holo-realtek-firmware-toggles` *(→ Alpha 4)*
- [ ] `cecd`, `cec-audio-control` — HDMI-CEC through a dock; needs dock *(→ Alpha 4)*
      hardware to test
- [ ] `steamos-log-submitter`, `steamos-kdumpst-layer` — crash reports, only *(→ Alpha 4)*
      without sending anything to Valve; would allow SteamOS's panic sysctls
- [ ] `steamos-customizations-jupiter`, parts not yet reviewed: `swap/`, *(→ Alpha 4)*
      `grub/`, `NetworkManager/`, `offload/` (`sleep.conf.d` belongs to the
      hibernate work in Alpha 4)

### Larger items

- [x] **`steam-jupiter`: Valve's Deck packaging of Steam**, layered on Void's
      `steam`. The biggest single step towards parity so far:
      - a preinstalled Steam client on the Deck's stable branch: the first
        start needs no download, cannot be interrupted halfway, and works
        offline
      - Valve's wrapper keeps Steam on `steamdeck_stable` (Io was on the
        desktop client's branch until now: an empty `package/beta`) and adds
        `-steamdeck -pipewire`; the command line now matches SteamOS exactly
      - udev rules for input, the status LED (so
        `STEAM_ENABLE_STATUS_LED_BRIGHTNESS` is set now) and wakeup
      - `libnm-32bit`: Steam's first-run setup offers Wi-Fi with the Deck's
        own controls
      - verified on a fresh image with no keyboard and no Ethernet: Steam
        starts directly, Wi-Fi setup and login work. `io-netcheck` is gone
- [ ] Screen recording without video — next step: `rec-dump.sh` on Io during *(→ Alpha 4)*
      a recording, compare with the SteamOS reference (see Alpha 2). Ruled
      out so far: `-pipewire`, the update branch, the missing 32-bit
      libraries (retested after `steam-jupiter` pulled in 48 of them)
- [ ] Wi-Fi backend: live test of iwd (SteamOS's default), then decide; if *(→ Alpha 4)*
      iwd, implement `SetWifiBackend`
- [x] Audio as on SteamOS, in one block:
      - ALSA loopbacks are created at runtime by an Io WirePlumber script
        ported from Valve's `CreateLoopback()`; the loopback carries the card
        identity, and Steam now shows its own localized names (verified by
        switching Steam to German)
      - the filter chain runs in its own PipeWire instance with Valve's
        quantum, locked memory and single malloc arena; `io-autologin` raises
        the memlock hard limit for it
      - speakers and headphones get no loopback: Valve's own 1.02 no longer
        marks sinks (SteamOS 3.8.4 ships 0.91, which does)
      - the audio block did not change screen recording
- [x] First boot without a keyboard: Steam's own first-run setup handles
      Wi-Fi (see `steam-jupiter`). `--retain-splash` stays off for now: it
      would hide the fallback shell on tty1
- [x] Boot time: the Steam UI now appears after 42 s instead of 54 s.
      `io-netcheck` polled `sv status`, which only root may run — it failed
      every time and waited its full 10 s on every boot; it now no longer
      runs at all. Open: a 4 s gap in the initramfs before `amdgpu` loads
      (zstd instead of gzip was tested: no difference)

### Interface and branding

- [ ] Plasma polish: largely done by `steamdeck-kde-presets`; left: messages *(→ Alpha 4)*
      when switching, the notification service requested in game mode,
      Valve's nested desktop (Plasma inside game mode)
- [ ] Designed boot splash; fill the black gap while Steam loads inside *(→ Alpha 4)*
      gamescope; check Io packages for remaining Valve graphics

### Also done

- [x] `steam-jupiter` replaces Void's `steam` completely, as Valve's package
      replaces Arch's: Valve's layout, its own dependency list (Void's plus
      Valve's 32-bit additions — 48 packages Io did not have before)
- [x] `build.sh` pulls `void-packages` first, so build dependencies come as
      binaries instead of being built from source

### Final state

Everything that was open went to Alpha 4, marked *(→ Alpha 4)* above.
Reached: Steam as on SteamOS (`steam-jupiter`: Deck branch, preinstalled
client, first boot without keyboard or network setup of Io's own), audio as
on SteamOS (loopbacks, filter chain, localized device names, ALSA through
PipeWire), vpower's controlled shutdown, mangoapp and gamemode, Valve's
Plasma defaults with Steam's keyboard in the desktop, and a boot 12 s
faster.

## Alpha 4 — Storage (next)

**Goal:** games on every drive the Deck can use, as on SteamOS — SD cards
and USB drives mount on their own and can be formatted from Steam. Beside
that, the loose ends carried over from Alpha 3.

### Storage

- [ ] Automount for SD cards and USB drives: Valve's `block-device-event.sh`
      and `steamos-automount.sh` on runit instead of `systemd-run`
      (`setsid --fork`), leaving out the boot device; Steam then offers the
      drive as a library
- [ ] Formatting from Steam: `steamos-format-sdcard` / `steamos-format-device`
      become real (Valve's `format-device.sh`)
- [ ] `steamos-trim-devices`
- [ ] Suspend-then-hibernate: Valve's `sleep.conf.d`, a swap area large enough
      for the RAM; check what that means on an SD card

### Loose ends from Alpha 3

- [ ] Screen recording without video (next: `rec-dump.sh` on Io during a
      recording, compare with the SteamOS reference)
- [ ] Wi-Fi backend: live test of iwd, then decide
- [ ] `steamos-powerbuttond` 3.1 → 4.2; kernel metapackage `linux-neptune`
- [ ] Stub helpers: confirm the decisions, record them on
      [Helper status](Helper-Status)
- [ ] Remaining Valve packages: `holo-sudo`, `steamos-networking-tools`,
      `steamos-systemreport`, `jupiter-firewall`,
      `holo-realtek-firmware-toggles`, `cecd`/`cec-audio-control`, crash
      reports (`steamos-log-submitter`, `kdumpst`, without sending anything
      to Valve), the rest of `steamos-customizations-jupiter`,
      `steam-web-debug-portforward` (developer mode)
- [ ] Boot: the 4 s gap in the initramfs before `amdgpu` loads; a designed
      splash; the black gap while Steam loads inside gamescope
- [ ] Plasma: messages when switching, the notification service in game mode,
      Valve's nested desktop
- [ ] Versioning of Io's own packages: content changes raise the version,
      packaging-only changes the revision; caught up whenever a package is
      touched anyway. 1.0 is reserved for the beta (`beta1.img`, `beta1.iso`)
- [ ] `io-selftest` and `io-boottime` shipped in a package, for bug reports

### Not in Alpha 4

- **Installing to the internal NVMe:** waits until no more SteamOS
  comparisons or captures are needed — the NVMe still holds SteamOS as the
  reference
- **Later:** SDDM, live ISO
- **For 1.0:** SSH off in images, replace the default password

## Candidates for later milestones

- **After a working 1.0 ISO: flavours**, the way Void offers several. The
  split is already prepared: `io-base` is the core, `io-desktop` adds the
  desktop. Candidates: *Plasma* (closest to SteamOS, today's image), *Base*
  (game mode only, no desktop), *Slim* (a light desktop, e.g. Openbox, with
  Io's own adjustments). Needs the ISO first, so the installer can offer the
  choice
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
