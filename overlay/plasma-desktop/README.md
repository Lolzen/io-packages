# plasma-desktop-holo

Replaces Void's `plasma-desktop`.

| Patch | Source | Upstream |
|---|---|---|
| `lockscreen-revert-vkb-wrapper-removal.patch` | Valve's plasma-desktop 6.8.2-3 (holo-main), `0001-Revert-lockscreen-drop-vkb-wrapper-use-KWinVirtualKe.patch`; context rebased onto 6.8.3 | Valve only (reverts an upstream change) |

Why: puts the lock screen's own on-screen keyboard (`VirtualKeyboardLoader`
from `plasma-workspace-holo`) back into `LockScreenUi.qml`; see
`overlay/plasma-workspace/README.md`. Both overlays belong together.

Left out of Valve's three patches: `0002` (the same revert for the SDDM
theme; does not apply to 6.8.3, and Io's SDDM logs in on its own with
`Relogin=true`, the greeter normally does not show) and `0003` (SDDM theme
wallpaper, same reason).

Applies to 6.8.3 after Void's `no-discover-recommendation.patch` and
`no-intltool.patch` without fuzz or offsets (2026-11-24).

Way back: with `plasma-workspace-holo`.
