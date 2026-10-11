# xorg-server-xwayland-holo

Replaces Void's `xorg-server-xwayland`.

| Patch | Source | Upstream |
|---|---|---|
| `revert-restrict-allow-commit-to-wm.patch` | Valve's xorg-xwayland 24.1.13-1.2 (SteamOS 3.9.2), `0001-Revert-xwayland-Restrict-allow-commit-to-the-window-.patch` (Vivek Das Mohapatra, Collabora, 2025) | a revert of upstream `2cc869626a`, which is in 24.1.13 |
| `revert-present-check-allow-commits.patch` | same, `0002-Revert-xwayland-present-Check-allow_commits-in-xwl_p.patch` | a revert of upstream `7c25024879`, which is in 24.1.13 |
| `libei-forward-text-as-keysyms.patch` | same, `0003-LibEi-keysyms.patch` (David Edmundson, KDE, 2026) | not in 24.1.13 |

Why:
- The two reverts ("seamless boot fixes" in Valve's PKGBUILD): Steam's
  `steamwebhelper` sets `_XWAYLAND_ALLOW_COMMITS` on its window and relies
  on the behaviour before these two upstream commits. With them, gamescope
  shows a short black interval instead of a seamless picture when Steam
  starts. Valve carries the reverts until Steam changes.
- libei keysyms: an X11 client's text input through XTEST (Steam's
  on-screen keyboard in the desktop) is forwarded to the compositor as
  keysyms instead of keycodes, so characters outside the first keyboard
  group and CJK text arrive correctly. It needs a compositor that accepts
  keysyms over libei: kwin's `Eis-Support-1.6-additions` (kwin-holo) and
  libei 1.6 (Void's libei 1.6.0 has it).

All three apply to the 24.1.13 sources (Valve's release tarball; Void
builds from the same tag).

Way back: drop the reverts when Valve does (Steam no longer needs the old
behaviour); drop the keysym patch once it is in an xwayland release Void
ships.
