# Pitfalls

Things that cost real time and are documented nowhere else.

---

## Steam client

**Many Steam features depend on launch flags and environment variables, not
on D-Bus.** *Restart Steam* in the power menu needs `-gamepadui` **and** Steam's
developer mode (Settings → System) — without developer mode it is hidden,
on SteamOS too; the
adaptive brightness toggle needs `STEAM_ENABLE_DYNAMIC_BACKLIGHT=1`; the fan
control toggle needs `STEAM_ENABLE_FAN_CONTROL=1`. Missing ones fail
silently — the control is just absent or greyed out, and no D-Bus call is
ever made. Copy Valve's `gamescope-session` environment instead of chasing
individual controls through D-Bus.

**Some Steam settings run helper scripts directly.** The fan control toggle
runs `steamos-polkit-helpers/jupiter-fan-control --enable/--disable`. A stub
that exits 0 makes Steam believe it worked.

**Steam drops audio sources without a fixed format.** A virtual source that
reports no channels while idle shows up through PipeWire's pulse layer as
`source not ready: sample:0 map:0` and is left out of Steam's microphone
list. Set `audio.channels` and `audio.position` on it.

**Never kill Steam with `pkill -9`.** It leaves state that cripples the next
start. A stale `~/.steam/steam.pipe` makes the next `steam.sh` exit silently
with status 0; delete it if Steam launches and immediately exits without
output.

**Steam's bootstrapper fails offline with a misleading "needs to be online"
message** whenever it has to download the client — with a plain bootstrap,
that is the first start. `steam-jupiter`'s preinstalled client avoids it.

**Steam's 32-bit bootstrapper needs `libcurl-32bit`.** Without it every
update check fails with a generic `http error 0` that reads like a network
problem.

**gamescope's process name is `gamescope-wl`**, not `gamescope`.

**An empty `package/beta` means the desktop client's branch.** Steam on
SteamOS runs on `steamdeck_stable`, set by Valve's wrapper before every
start. Without it, a Deck gets the generic Linux client.

**Steam localizes audio device names itself**, from the card identity
(`device.id`, `card.profile.device`) on the node. Without it Steam falls back
to the raw `node.name` — which is also why it shows the node name and not the
description for such sources.

---

## runit, D-Bus and sessions

**A service must not be both a runit service and D-Bus-activated.** At boot
they race; the loser restarts every second, forever. Seen with elogind
(runit service kept, activation file removed) and polkitd (runit service
removed, D-Bus activation kept). The loop is invisible without a syslog:
`polkitd` restarted every second for a long time before a syslog made it
visible.

**Without a syslog, runit service logs disappear.** Void's services log
through `vlogger` to `/dev/log`; with nothing listening there, every message
is lost. `socklog-void` fixes it.

**runit starts services in parallel.** earlyoom with a swap threshold (`-S`)
refuses to start while there is no swap yet ("exceeds limit 0"); it has to
wait for the zram service itself.

**`modprobe zram num_devices=1` only creates devices on the first load.** If
the module is already loaded, nothing happens. `zramctl --find` creates a
device through the kernel's `hot_add` interface in any state.

**acpid and elogind fight over the power button.** Either disable acpid or
set every `Handle*` option in `logind.conf` to `ignore`; half of each means
elogind ignores the button while acpid's `handler.sh` shuts the machine down.

**`exec` in a sourced script replaces the parent.** Void's `/etc/runit/1`
sources `core-services/*.sh` with `.`; a core service ending in
`exec something` replaces runit's stage 1 process, and all remaining core
services are silently skipped.

**`sv status` only works as root.** Run as a user it fails with
`access denied` — a wait loop on it simply runs into its timeout, every
time. `io-netcheck` lost 10 s per boot this way. Use a tool the user may run
(`nm-online`, `pgrep`).

**X sockets in `/tmp/.X11-unix/` survive a session.** Waiting for `X0` to
appear before starting an overlay or helper therefore succeeds immediately,
with the socket of the session that just ended. Wait for the process
(`pgrep -x gamescope-wl`) as well.

**Process names are cut to 15 characters.** `pgrep -x`/`pkill -x
steamos-powerbuttond` never match; use `-f` with the path.

**Never start WirePlumber by hand.** Void's PipeWire starts it through a
symlink in `/etc/pipewire/pipewire.conf.d/`; a second instance gives an
`auto_null` sink and a gamescope without a window, with no useful error.

**libseat prefers seatd whenever its socket exists**, and without the
`_seatd` group gamescope then gets `Permission denied` and falls back to a
headless backend: a black screen with a normal-looking log. Io no longer
runs seatd; libseat uses elogind, as gamescope does on SteamOS through
logind.

**Never pipe a session into a logger and wait for the pipe.** `session |
svlogd` only ends when every process holding the write end has exited.
Processes that outlive the session (PipeWire's pulse server did) keep it
open forever: the next session never starts, the screen stays on an empty
tty. Log through a FIFO and wait for the session process only.

**Environment set in a session script does not reach D-Bus-activated
services.** They inherit the bus daemon's environment. Use
`dbus-update-activation-environment VAR` (Valve uses `systemctl --user
set-environment`). Needed for `XDG_DESKTOP_PORTAL_DIR`: without it, game
mode starts every installed portal backend, and Plasma's KDE and GTK
portals crash there over and over.

**Void ships the VA-API driver separately** (`mesa-vaapi`, `-32bit`). Without
it `vainfo` fails and Steam never creates a video encoder for recordings.
Steam's runtime diagnostics (`steam-runtime-system-info-*.txt` in Steam's
`logs/`) are only rewritten when Steam's system information page is opened,
so an old file can show an already fixed error.

**PipeWire outlives the session that started it**, still attached to that
session's D-Bus bus. `io-start` ends it when the session ends. When testing
audio configuration changes by hand, a cold boot is still the reliable way.

---

## Packaging (xbps-src)

**Never ship or patch files that belong to another package.** A file owned by
two packages is silently overwritten or removed by the other's updates; a
file patched at image build time (as `mkimg.sh` once did to
`/etc/profile.d/io-session.sh`) loses the patch on the owning package's next
update. Use drop-in directories, own service directories, or ship the file
in the package that owns it.

**Bump `revision` for every change.** Same version and revision means the
same file name; the new build is treated as already published.

**`xbps-install -Su <package>` does not update that package's
dependencies**, it only installs missing ones. Update with plain
`xbps-install -Su`.

**`post_install()` is a build-time hook.** It runs during `xbps-src pkg`,
never on the target at install time. Code for install time goes into
`srcpkgs/<pkg>/INSTALL`, using `$ACTION`.

**`post_extract` is not run in templates without a `build_style`.** Put the
checkout step at the start of `do_install`.

**`xbps-install -r` before `/proc`, `/dev` and `/sys` are bind-mounted defers
every `INSTALL` script silently.** Follow up with `xbps-reconfigure -a` once
the mounts are in place.

**`/etc/sysctl.d` is rejected by Void's package linter.** Packages ship
defaults in `/usr/lib/sysctl.d`.

**`vcopy` does not create its destination directory**, unlike `vinstall` and
`vbin`. Add a `vmkdir` first.

**`python_version=3` is required** in any template shipping a Python script,
or the shebang rewrite aborts the build.

**Rust packages do not need Arch's vendored crate lists.** `build_style=cargo`
resolves crates itself. Crates that generate bindings (`clang-sys`) also need
`clang`, `llvm` and `clang21-devel`: the versioned `-devel` package is the only
one shipping the unversioned `libclang.so` that `clang-sys` looks for.

**A git repository in Valve's archive can be named like the program being
built** (`steamos-powerbuttond`): `ld` then fails with "Is a directory".
Unpack the tree into a subdirectory and set `build_wrksrc`.

**After a failed build `post_extract` does not run again** — `xbps-src`
remembers the extraction. `./xbps-src clean <package>` first.

**Check which git tag you unpack from Valve's archive.** The newest tag in
`git tag | tail -1` sorts alphabetically, not by date; use the tag that
matches the package version (`jupiter-20260827.2`), or you review an old
tree.

**`tar` is not in the build chroot by default.** A `post_extract` that unpacks
Valve's git archive (`git archive … | tar -x`) needs `hostmakedepends="git
tar"`, or it fails with `tar: command not found`.

**A heredoc write or append can silently do nothing or lose its last line.**
Happened three times (PipeWire configuration, kernel configuration fragment).
`cat` the file after writing it.

---

## Kernel and hardware

**iwd recreates the Wi-Fi interface under the kernel name (`wlan0`).** With
predictable interface names udev renames it right away (`wlo1`), and
NetworkManager then looks for an interface that no longer exists — Wi-Fi
"unavailable" after any iwd restart. SteamOS keeps kernel names; Io sets
`net.ifnames=0`.

**iwd removes the interface it created when it exits — with a delay.**
Switching from iwd to wpa_supplicant has to wait until iwd is gone before
checking for (and recreating) `wlan0`, or the interface vanishes after
NetworkManager has already picked it up.

**NetworkManager passes `wifi.powersave` only to wpa_supplicant.** With iwd
as backend it is ignored; iwd takes `[DriverQuirks] PowerSaveDisable` from
its own `main.conf`.

**The kernel package deletes its bundled firmware** on purpose, expecting Void's
`linux-firmware` packages; it needs an explicit
`depends="linux-firmware-amd linux-firmware-network"`, or the Deck boots with
a dead GPU and no Wi-Fi.

**`force_drivers+=" amdgpu "` in the dracut configuration is mandatory.**
Without the module in the initramfs the screen stays black through early KMS.

**dracut silently falls back to gzip** when `compress="zstd"` is set but the
`zstd` program is missing. Check the first bytes after the early cpio
(`/usr/lib/dracut/skipcpio`), not the configuration.

**Valve's kernel tree contains two configuration files.**
`ci/kernel-config/neptune/config` is a full 12,500-line reference used for CI;
`ci/kernel-config/neptune/config-neptune` is the fragment that is actually
merged. An option only in the first one never applies.

**The CS35L41 amplifier firmware is in Void's main `linux-firmware`
package**, not in the split ones (`-amd`, `-network`) the kernel pulls in.
Without it one speaker stays silent. With it, the amplifiers load the
Deck-specific `cs35l41-dsp1-spk-prot-vlv1776.*` files.

**Void does not route ALSA through PipeWire by default.** `alsa-pipewire`
ships `50-pipewire.conf` and `99-pipewire-default.conf` in
`/usr/share/alsa/alsa.conf.d/`, but they only take effect when linked into
`/etc/alsa/conf.d/`. Without the links ALSA's default device tries to open
the hardware PipeWire already holds (`unable to open slave`), and the
`pipewire` device is unknown. Steam and Proton are unaffected (they use the
pulse layer), which is why it went unnoticed.

**`EV_FF` is bit `0x200000`** in `/proc/bus/input/devices`, not `0x100000`.

**A warm reboot can boot a different OS.** With Io on an SD card (GRUB in
removable mode, no NVRAM entry) next to an internal SteamOS, a warm reboot
skips the boot selector and starts whatever owns the NVRAM default. From the
outside it looks like a broken Io service until you see the other system's
login prompt.

---

## First boot

**`plymouth quit --retain-splash` leaves the console in graphics mode.**
Text written to tty1 afterwards is not drawn at all — during Alpha 2 a
first-boot network prompt waited invisibly for input on every fresh image,
and only there, because a development card already knows its Wi-Fi. The
fallback shell would be just as invisible. Test first boot with a fresh
image, not on a development card.

**An interrupted first Steam download leaves Steam broken** — only relevant
with a plain Steam bootstrap. `~/.local/share/Steam/steam.sh` stays empty but
executable, and the launcher runs it every time (`Exec format error`).
Removing the empty file makes the launcher set Steam up again. With
`steam-jupiter`'s preinstalled client there is no first download.

**A fresh Steam profile has fan control off** and applies that at start,
stopping `jupiter-fan-control` on purpose (`down … normally up`). Not a
failure.

---

## Desktop

**Without Steam running, the desktop freezes whenever something reopens
the controller.** Opening the Deck's controller (for example Plasma's game
controller settings page, through SDL) makes `hid-steam` drop its mouse and
keyboard emulation for a moment — the pointer and everything with it stops.
With Steam running in the background, as on SteamOS, Steam holds the
controller.

**Steam's on-screen keyboard in the desktop grows past the screen** when
Steam scales with the desktop's DPI (Plasma at 135 %: `Xft.dpi` 129). Steam
sizes the keyboard for 1280 pixels and then enlarges it. Steam's own
setting fixes it (`DPIScaling` 0 in `~/.steam/registry.vdf`);
`STEAM_FORCE_DESKTOPUI_SCALING` does not.

---

## Audio

**A loopback bound with `target.object` at startup can bind to nothing and
never retry**, if its target node does not exist yet. It looks complete,
suspended and correct in `wpctl` and `pw-dump`. Set `target.delay.sec`, and
verify with an actual recording (`pw-record`), not with the node list.

**Valve's `filter-chain.conf.d/` belongs to a second PipeWire instance.** It
only takes effect when that instance runs (`pipewire -c filter-chain.conf`,
`filter-chain.service` on SteamOS). Valve's two `context-properties` files are
therefore not alternatives: the one in `pipewire.conf.d/` configures the main
daemon, the one in `filter-chain.conf.d/` the filter instance. Merging them
applies the filter chain's fixed quantum and `mem.mlock-all` to everything.

**`probe_volumes: Path X is not a volume or mute control` warnings are
harmless.** They come from the generic mixer paths in `alsa-card-profile` and
cannot be fixed from a device package.

**A PipeWire client started before the daemon's socket exists just exits**,
it does not retry. systemd orders this through socket activation; a session
script has to wait for `$XDG_RUNTIME_DIR/pipewire-0` itself.

**The version of a Valve package on a running SteamOS is not the newest one.**
`steamdeck-dsp` is 0.91 on SteamOS 3.8.4 but 1.02 on Valve's mirror, and they
behave differently (1.02 no longer creates loopbacks for sinks). Check the
source of the version you package, not only the installed files.

**Separate Valve patches from upstream before chasing a difference.** Valve
ships patched builds of some packages (WirePlumber's `CreateLoopback()` is
one). Compare against the upstream release, not against SteamOS's installed
files.

---

## Valve packages

**`jupiter-hw-support` 20260807.1 renames the helpers to `holo-*`**, with
`steamos-alias` (a pacman hook) linking the old names back. Steam and
SteamOS 3.8.4 still use `steamos-*`. Io keeps the old names and takes only
the real changes; there is no xbps equivalent of the hook.

**Valve's `holo-upower-config` has no effect as shipped.** It sets
`AllowRiskyCriticalPowerAction=yes`; UPower accepts only `true`/`false` and
falls back to HybridSleep with a warning.

**vpower hardcodes `steamdeck-hwmon/hwmon/hwmon3`.** The hwmon index depends
on the kernel (`hwmon6` on Io's 7.2); without a patch vpower assumes a 100 %
charge limit.

**`deck-hw-support`'s udev rules call `/bin/systemd-run`**, which does not
exist under runit, and the automount rule calls `busctl` against udisks2 —
including for the boot device during coldplug, before D-Bus exists. Replace
`systemd-run` with `setsid --fork` and exclude the boot device before
enabling automount.

**`steamos-priv-write` needs two edits:** `chgrp deck` becomes `chgrp wheel`
(matching Valve's polkit rule), and `systemd-cat` becomes `logger`.

**Valve's `python<3.14` constraints were too conservative** and have been
relaxed upstream.

---

## Shell and tools

**`sudo` resets the environment.** A terminal type the Deck does not know
(`rxvt-unicode-256color`) breaks `sudo nano`; use
`sudo TERM=xterm-256color nano ...`.

**Wildcards are expanded by your own shell before `sudo` runs.** For paths
only root can list, run the whole command under `sudo sh -c '...'`.
