# plasma-workspace-holo

Replaces Void's `plasma-workspace`, `kworkspace`, `plasma-workspace-x11` and
`plasma-workspace-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `lockscreen-qt-virtual-keyboard.patch` | Valve's plasma-workspace 6.8.2-1.2 (holo-main and holo-3.10), `0001-Show-Qt-Virtual-Keyboard-in-process-on-the-lockscree.patch` (David Edmundson, 2026-11-02) | not upstream |

Why: Plasma 6.8 dropped the lock screen's own on-screen keyboard; the lock
screen asks kwin's input method instead (`KWinVirtualKeyboard`). On the
Deck that is only there when `plasma-keyboard` is chosen as the virtual
keyboard, which SteamOS and Io leave off by default (see Deviations), so
the password field of the lock screen would have no keyboard. Valve brings
the in-process keyboard back: this patch adds the `VirtualKeyboard` and
`VirtualKeyboardLoader` components (Qt Virtual Keyboard) to the
look-and-feel components; `plasma-desktop-holo` puts them back into the
lock screen. Both overlays belong together.

`template.append`: depends on `qt6-virtualkeyboard` (Arch and Valve do;
Void's plasma-workspace does not, `plasma-keyboard` pulls it in on Io).

Applies to 6.8.3 after Void's `fix-krunner-cwd.patch` without fuzz
(2026-11-24); not compiled here.

Way back: when Plasma brings a lock screen keyboard that works without
kwin's input method, or Valve drops the patch.
