<img src="srcpkgs/io-branding/files/io-logo.svg" alt="Io logo" width="140" align="right">

# Io

A Void Linux rebuild of SteamOS for the Steam Deck. No systemd.

Io is a moon of Jupiter and the most volcanically active world in the solar
system. The sulphur it throws into space forms a plasma ring around Jupiter,
the Io torus. Hence the logo: a ring around a gas giant, with the moon that
creates it sitting on the ring.

> **Status:** working prototype on an SD card. Boots, plays games, switches
> between game mode and desktop. Packaging and ISO are still ahead.

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

## Packages

| Package | Contents |
|---|---|
| `linux-neptune` | Kernel 6.15.8 from the kernel.org tarball plus Valve's patch set and the Deck config fragment |
| `deck-firmware-cirrus` | CS35L41 DSP firmware for the speaker amplifiers |
| `deck-hw-support` | Valve's polkit helpers, udev rules and hwsupport scripts, trimmed and stubbed |
| `jupiter-fan-control` | Valve's fan daemon, unmodified, wrapped in a runit service |
| `steamos-powerbuttond` | Valve's power button daemon, systemd unit replaced |
| `io-base` | Repository config, elogind drop-in, dracut snippet, polkit rules |
| `io-branding` | os-release, ASCII and SVG logo, fastfetch config |
| `io-session` | Game mode startup, session switching, autologin service |
| `io-volumed` | Volume key handler (Steam shows the OSD but does not set the level) |
| `io-desktop` | Metapackage tying everything together |

The kernel is not maintained as a fork. Valve's delta is a single patch against
the official tarball, and the config fragment comes unchanged from the
jupiter-PKGBUILD mirror. A version bump means a new tag, a new patch and a new
fragment.

### Upstream sources

Most packages are built from Valve's source mirrors. Note that the GitLab
mirror at `gitlab.com/evlaV` was shut down in August 2025; `github.com/evlaV`
is the successor and the active source. Existing distfile URLs still resolve,
but check GitHub first when bumping versions.

---

## What works

**Boot and hardware**

- Boots on the Steam Deck LCD with correct panel rotation
- Graphics through radv on Van Gogh, gamescope directly on DRM
- Audio through both CS35L41 amplifiers, headphones and internal microphone
- WLAN through NetworkManager
- Suspend and resume, including wake via the power button
- Fan control through Valve's daemon (idles at 1500 rpm, ramps above 55 °C)

**Game mode**

- Cold boot lands directly in Steam, no login prompt
- Steam runs with `-steamdeck -steamos3`, which enables the SteamOS system menu
- Controller works fully: sticks, trackpads, Steam button, overlay
- Volume keys change the volume and the OSD follows
- Brightness slider works (through `steamos-priv-write`)
- Power off from the Steam menu works
- Power button suspends and wakes the device
- Proton runs — tested with Magic: The Gathering Arena, including sound

**Session switching**

- Steam menu → *Switch to Desktop* brings up Plasma within a few seconds
- A desktop shortcut brings you back to game mode
- Plasma has correct rotation, working touchscreen and working trackpads

**Branding**

- `Io` appears in fastfetch and in the Steam system menu

### How session switching works

There is no display manager and no systemd. The chain is
`agetty → .bash_profile → io-start → dbus-run-session → io-gamemode → gamescope`.

Steam calls `steamos-session-select`, which only writes a state flag to
`$XDG_RUNTIME_DIR` — it runs inside the pressure-vessel container, where
`pgrep` and `pkill` cannot see the host processes. A watcher started by
`io-gamemode` polls that flag and terminates gamescope when it changes. runit
respawns tty1, autologin fires again, and `io-start` reads the flag to decide
which session to start.

`.bash_profile` guards against boot loops: if the session dies in under 15
seconds it drops to a shell instead of restarting.

---

## What is open

### Small

- [ ] `timedatectl` is missing; Steam calls it twice at startup and the
      timezone cannot be set from the client
- [ ] `jupiter-amp-control` is a stub — the target script is not in any
      available mirror. Audio works without it
- [ ] `steamos-reboot-other` is a stub; it belongs to SteamOS A/B updates,
      which Io does not have
- [ ] Bump revisions consistently; several packages still carry numbers from
      testing

### Needs work

- [ ] **Gyro and back buttons.** `inputplumber` would cover this, but it is a
      Rust package with ~250 vendored crates, it defaults to
      `auto_manage: false` on the Deck, and it would replace the working
      controller with an emulated Xbox device. Not obviously worth it
- [ ] **TDP and charge limit.** The menu entries exist under `-steamos3` but do
      nothing. This needs `steamos-manager`, which hard-depends on systemd and
      vendors ~190 crates. Deferred indefinitely
- [ ] **Screen capture.** `xdg-desktop-portal-wlr` fails in game mode, which
      affects screenshots and streaming
- [ ] **`CAP_SYS_NICE` for gamescope.** Would silence the performance warning,
      but file capabilities put the process into secure execution mode, which
      makes some Vulkan environment variables get ignored — including,
      possibly, `vk_xwayland_wait_ready`, which Io depends on. Testable in one
      command and reversible in one, but not a priority

### Infrastructure

- [ ] Publish the signed package repository as a GitHub release; the URL in
      `io-base` currently points nowhere
- [ ] Wiki: installation, pitfalls, kernel bump procedure
- [ ] GitHub Actions for automated builds (optional)
- [ ] ISO through `void-mklive` once the metapackage is complete

### Larger decision

- [ ] **Move to the internal NVMe.** The SD card is too slow for games and has
      caused several timing-related failures during development.

---

## Pitfalls

Things that cost real time and are documented nowhere.

**Never start wireplumber manually.** Void configures PipeWire to launch the
session manager itself through a symlink in `/etc/pipewire/pipewire.conf.d/`.
Starting wireplumber separately creates a second instance. The symptoms are an
`auto_null` sink instead of the real devices *and* a gamescope that runs but
shows no window — with no useful error message anywhere.

**elogind must not start twice.** Void enables the runit service, but dbus also
ships an activation file with `Exec=`. At boot they race; if runit loses, it
retries every second and the session never settles. Disable the activation
file.

**acpid and elogind fight over the power button.** The Void handbook is
explicit: either disable acpid, or set every `Handle*` option in `logind.conf`
to `ignore`. Doing half of each means elogind politely ignores the button while
acpid's `handler.sh` shuts the machine down.

**Set `vk_xwayland_wait_ready=true`** before gamescope on slow storage.
Otherwise Steam starts before Xwayland is ready and none of its windows are
ever mapped.

**Never kill Steam with `pkill -9`.** It leaves state that cripples the next
start. `~/.local/share/Steam/.crash` indicates the last run ended badly.

**gamescope's process name is `gamescope-wl`**, not `gamescope`. Every
`pgrep -x gamescope` silently matches nothing.

**Do not update `io-session` while game mode is running.** The installed
scripts end up empty.

**The CS35L41 needs two firmware files** that are not in Void's
`linux-firmware`: `cs35l41-dsp1-spk-prot.wmfw` and
`cs35l41-dsp1-spk-prot-vlv1776.bin` from `linux-firmware-neptune`. Without them
one speaker stays silent. No mixer gymnastics are needed beyond that —
wireplumber handles channel assignment through the UCM profile.

**`force_drivers+=" amdgpu "` in the dracut config is mandatory.** Without the
module in the initramfs the screen stays black through early KMS.

**`python_version=3` is required** in any template shipping a Python script,
or the shebang rewrite hook aborts the build.

**Valve's `python<3.14` constraints are too conservative.** Both
`jupiter-fan-control` and the hw-support scripts run fine on 3.14.

**`steamos-priv-write` needs two edits** for Void: `chgrp deck` becomes
`chgrp wheel` (matching Valve's own polkit rule, which checks group membership
in `wheel`), and `systemd-cat` becomes `logger`.

---

## Helper status

`deck-hw-support` ships all 22 of Valve's polkit helpers so the policy file
stays intact, but many of them are stubs. Keeping the entries prevents polkit
actions from pointing at missing paths.

**Real:** `steamos-priv-write`, `steamos-poweroff-now`, `steamos-reboot-now`,
`jupiter-check-support`, `jupiter-get-als-gain`, `steamos-set-hostname`,
`steamos-set-timezone`, `steamos-trim-devices`,
`steamos-disable-wireless-power-management`

**Stubbed, target missing:** `jupiter-amp-control`, `steamos-reboot-other`

**Stubbed, needs systemd:** `jupiter-fan-control`, `steamos-devkit-mode`,
`steamos-enable-sshd`, `steamos-restart-sddm`

**Stubbed, dangerous or pointless here:** `jupiter-biosupdate`,
`jupiter-dock-updater`, `steamos-format-device`, `steamos-format-sdcard`,
`steamos-factory-reset-config`, `steamos-update`, `steamos-select-branch`

Steam looks for `steamos-update` and `steamos-select-branch` under `/usr/bin`,
not only in the helper directory, so symlinks are installed for both.

---

## License

MIT for Io's own packages. Firmware blobs, Valve patches and vendored upstream
code carry their own licenses; each package declares its own `license=` field.
