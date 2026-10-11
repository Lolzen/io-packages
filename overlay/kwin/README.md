# kwin-holo

Replaces Void's `kwin` and `kwin-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `load-current-brightness-from-device.patch` | Valve's kwin 6.7.3-1.6 (SteamOS 3.9.2), `0002-Load-current-brightness-from-device.patch` | not upstream (KDE bug 508163) |
| `inputmethod-skip-fake-input-events.patch` | same, `0006-inputmethod-Skip-input-events-from-fake-input.patch` (David Edmundson) | not upstream ("currently deck specific") |
| `eis-support-libei-1.6-additions.patch` | same, `0011-Eis-Support-1.6-additions.patch` | `f2d11255e1`, kwin 6.8 (not in 6.7.5) |
| `drm-filter-unusably-small-modes.patch` | same, `0013-filter-bad-modes.patch` | `a64249da3c`, kwin 6.8 (not in 6.7.5) |

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

Valve's `0001-Handle-WM_TAKE_FOCUS-more-gracefully` is already in 6.7.5 and
stays out. All four apply to 6.7.5 after Void's `cross.patch`, in the order
holo.sh applies them.

Way back: 0011 and 0013 come with kwin 6.8; drop them at Void's 6.8 bump.
0002 and 0006 stay until they are upstream or Valve drops them.
