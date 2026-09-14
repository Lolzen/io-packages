# Architecture

## Distribution

Io ships as a disk image, not a live ISO. The hardware is fixed, the partition
layout is fixed, and there is nothing for an installer to ask — writing the
image with `dd` is the whole installation.

The live-ISO route is blocked: dracut 112 changed its live-boot logic and
void-mklive has not caught up, so self-built ISOs drop to an emergency shell.
`mkimg.sh` builds the disk image directly instead.

## Session switching

There is no display manager and no systemd. The chain is
`agetty --autologin → /etc/profile.d/io-session.sh → io-start → dbus-run-session → io-gamemode → gamescope`.

`io-session.sh` guards against boot loops: if the session dies in under 15
seconds it drops to a shell instead of restarting.

**Switching to desktop** goes through `io-steamos-manager`, a from-scratch
Python reimplementation of Valve's `com.steampowered.SteamOSManager1` DBus
interface (Valve's own daemon hard-depends on systemd, so it isn't just
repackaged). Steam calls its `SwitchToDesktopMode` method directly over DBus
— confirmed via `dbus-monitor` — rather than going through the older
`steamos-session-select` + flag-file mechanism.

`io-steamos-manager` runs inside game mode's `dbus-run-session` and exits
with it, so nothing is running once Plasma comes up. **Switching back to
game mode** therefore still uses the original path: a desktop shortcut runs
`steamos-session-select`, which writes a state flag to `$XDG_RUNTIME_DIR`.
Since `steamos-session-select` runs inside Steam's pressure-vessel
container, it can't see host processes directly — a watcher started by
`io-gamemode` polls the flag and terminates gamescope when it changes. runit
respawns tty1, autologin fires again, and `io-start` reads the flag to
decide which session to start next.

## First boot

Two things run before the first login, injected directly by `mkimg.sh`
rather than shipped in a package (see [Pitfalls](Pitfalls) for why):

- `io-netcheck` blocks tty1 until a network connection exists (Ethernet or
  WiFi, including dock-provided Ethernet) — Steam's bootstrapper cannot do
  anything meaningful without one. Skipped on repeat logins within the same
  boot via a boot-ID-tagged flag in `~/.cache`.
- The root partition is grown to fill the actual card (12G image → however
  large the card is) via `cloud-guest-utils`'s `growpart`, wrapped with a
  visible on-console warning not to power off mid-resize.