# kwin-holo

Replaces Void's `kwin` and `kwin-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `load-current-brightness-from-device.patch` | Valve's kwin 6.7.3-1.6 (SteamOS 3.9.2), `0002-Load-current-brightness-from-device.patch` | not upstream (KDE bug 508163) |
| `inputmethod-skip-fake-input-events.patch` | same, `0006-inputmethod-Skip-input-events-from-fake-input.patch` (David Edmundson) | not upstream ("currently deck specific") |
| `eis-support-libei-1.6-additions.patch` | same, `0011-Eis-Support-1.6-additions.patch` | `f2d11255e1`, kwin 6.8 (not in 6.7.5) |
| `drm-filter-unusably-small-modes.patch` | same, `0013-filter-bad-modes.patch` | `a64249da3c`, kwin 6.8 (not in 6.7.5) |
| `workspace-1-screens-off-before-suspend.patch` | Valve's kwin 6.7.3-1.7 (main, not in SteamOS 3.9.3), `0001-workspace-turn-screens-off-before-suspend-again.patch` (Xaver Hugl) | `26a9560`, kwin master 2026-10-19 (MR 10127), not in Plasma/6.7 |
| `workspace-2-correctly-delay-suspend.patch` | same, `0002-workspace-correctly-delay-suspend.patch` | `e6932b4`, same |
| `workspace-3-no-sleep-inhibition-without-outputs.patch` | same, `0003-workspace-remove-sleep-inhibition-while-no-outputs-a.patch` | `b19214e`, same |

Why:
- Brightness: when kwin picks up the backlight, it takes the device's
  current brightness instead of the value it saved, so the desktop keeps
  the brightness set in game mode. Io did this without a kwin build
  (`io-plasma` writes the value into kwin's output configuration before kwin
  starts); with this patch that step can go.
- Fake input: Steam's on-screen keyboard commits whole keysyms through
  libei. While another input method that grabs the keyboard is active in
  kwin (`plasma-keyboard`), they were passed to it and lost. Input from
  libei now goes straight to the client; a physical keyboard still goes
  through the input method.
- libei 1.6: kwin accepts keysym and text events from libei, which
  `xorg-server-xwayland-holo`'s keysym forwarding sends (characters outside
  the first layout group, CJK). Needs libei 1.6 (Void has 1.6.0).
- Small modes: modes below 480p are not offered (unless a display has no
  other), so an external display cannot be set to an unusable mode by
  mistake.
- Suspend: kwin turns the screens off itself before the system sleeps (it
  had left that to powerdevil; if powerdevil does not, the screen stays on
  and can show its contents while it locks), holds its sleep delay
  whenever screens are on instead of asking for it in PrepareForSleep
  (refused there), and drops it while no output is connected. Valve: fixes
  a frozen screen and looping sound during hibernation on the Steam Machine
  (task 2320). On Io this is the desktop session (game mode is gamescope);
  elogind offers the same PrepareForSleep and delay inhibitors.

Valve's `0001-Handle-WM_TAKE_FOCUS-more-gracefully` is already in 6.7.5 and
stays out. All seven apply to 6.7.5 after Void's `cross.patch`, in the order
holo.sh applies them.

Way back: 0011, 0013 and the three workspace patches come with kwin 6.8
(the workspace ones are on master; check the 6.8 release); drop them at
Void's 6.8 bump.
0002 and 0006 stay until they are upstream or Valve drops them.
