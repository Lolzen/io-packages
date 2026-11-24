# kwin-holo

Replaces Void's `kwin` and `kwin-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `input-1-init-backends-after-redirection.patch` | Valve's kwin 6.8.2-1.4 (jupiter-main, 2026-11-24), `0009-fix-input-crash.patch` (Xaver Hugl) | `a96ceac`, kwin master 2026-11-17 (KDE bug 528824), not in 6.8.3 |
| `input-2-libinput-only-add-events-on-startup.patch` | same, `0010-add-events-on-startup.patch` (Xaver Hugl) | `9f86763`, kwin master 2026-11-21 (KDE bug 528936), not in 6.8.3 |
| `inputmethod-skip-fake-input-events.patch` | same, `0006-inputmethod-Skip-input-events-from-fake-input.patch` (David Edmundson); one hunk's context rebased onto 6.8.3, the added lines are Valve's | not upstream ("currently deck specific") |
| `load-current-brightness-from-device.patch` | same, `0002-Load-current-brightness-from-device.patch`; line numbers rebased onto 6.8.3 | not upstream (KDE bug 508163) |

Why:
- Input start-up (input-1, input-2): kwin starts its input backends only
  after its input redirection exists, so a backend that sends an event
  while it starts can no longer crash kwin; and during start-up libinput's
  events other than "device added" wait until kwin's input filters are
  set up, so a switch state (lid, tablet mode) sent only once at start is
  not lost.
- Fake input: Steam's on-screen keyboard commits whole keysyms through
  libei. While another input method that grabs the keyboard is active in
  kwin (`plasma-keyboard`), they were passed to it and lost. Input from
  libei now goes straight to the client; a physical keyboard still goes
  through the input method. kwin 6.8.3 has an environment variable for the
  same purpose (`KWIN_DEVICE_SKIPS_INPUT_METHOD`, a list of device names);
  Valve keeps its patch, so does Io.
- Brightness: when kwin picks up the backlight, it takes the device's
  current brightness instead of the value it saved, so the desktop keeps
  the brightness set in game mode. Io did this without a kwin build
  (`io-plasma` writes the value into kwin's output configuration before kwin
  starts); with this patch that step can go.

In kwin 6.8.3 and dropped from the overlay (were Io's patches on 6.7.5):
libei 1.6 keysym and text events (`f2d11255e1`), no modes below 480p
(`a64249da3c`, upstream now also keeps a display's preferred mode), and
the three suspend patches of MR 10127 (screens off before suspend, sleep
delay held while screens are on, none without outputs). Valve's 0007/0008
(libinput devices listed during set-up, so the lid is known; a default
scale for handhelds and tablets instead of a phone's) are in 6.8.3 as
well.

All four apply to 6.8.3 after Void's `cross.patch`, in the order holo.sh
applies them, without fuzz or offsets (checked 2026-11-24). Not compiled
here (kwin needs Qt 6.11 and KDE Frameworks this container does not have);
Valve builds the same four on 6.8.2.

Way back: input-1 and input-2 are on kwin master; drop them when a kwin
release Void takes has them. The fake input and brightness patches stay until
they are upstream or Valve drops them.
