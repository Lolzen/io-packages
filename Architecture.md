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

Steam calls `steamos-session-select`, which only writes a state flag to
`$XDG_RUNTIME_DIR` — it runs inside the pressure-vessel container, where
`pgrep` and `pkill` cannot see the host processes. A watcher started by
`io-gamemode` polls that flag and terminates gamescope when it changes. runit
respawns tty1, autologin fires again, and `io-start` reads the flag to decide
which session to start.

`io-session.sh` guards against boot loops: if the session dies in under 15
seconds it drops to a shell instead of restarting.

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