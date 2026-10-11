# xorg-server-xwayland-holo

Replaces Void's `xorg-server-xwayland`.

| Patch | Source | Upstream |
|---|---|---|
| `libei-forward-text-as-keysyms.patch` | Valve's xorg-xwayland 24.1.13-1.2 (SteamOS 3.9.2), `0003-LibEi-keysyms.patch` (David Edmundson, KDE, 2026) | not in 24.1.13 |

Why: an X11 client's text input through XTEST (Steam's on-screen keyboard
in the desktop) is forwarded to the compositor as keysyms instead of
keycodes, so characters outside the first keyboard group and CJK text
arrive correctly. It needs a compositor that accepts keysyms over libei:
kwin's `Eis-Support-1.6-additions` (kwin-holo) and libei 1.6 (Void's libei
1.6.0 has it). Tested on the Deck: German letters and emoji from Steam's
keyboard arrive in the desktop; `€` (AltGr level) does not.

Left out on purpose: Valve's two "seamless boot" reverts
(`0001-Revert-xwayland-Restrict-allow-commit-to-the-window-.patch`, revert of
upstream `2cc869626a`; `0002-Revert-xwayland-present-Check-allow_commits-in-xwl_p.patch`,
revert of `7c25024879`). Valve carries them so that Steam's
`steamwebhelper` shows its first picture under gamescope without a black
interval. On Io they did the opposite: returning from the desktop to game
mode showed a black flash with them (io_revision 1) and none without them
(io_revision 2, tested 2026-10-11). Without them, and with kwin-holo, the
desktop's last picture stays on screen until Steam's boot animation, as on
SteamOS.

The patch applies to the 24.1.13 sources (Valve's release tarball; Void
builds from the same tag, same checksum).

Way back: drop it once it is in an xwayland release Void ships.
