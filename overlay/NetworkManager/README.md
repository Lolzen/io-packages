# NetworkManager-holo

Replaces Void's `NetworkManager`, `libnm` and `NetworkManager-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `wifi-scan-only-last-associated-freq-after-resume.patch` | Valve's networkmanager 1.58.0-1.8 (SteamOS 3.9.2), `0001-wifi-supplicant-scan-only-the-last-associated-freq.patch` (Vignesh Raman, Collabora, 2026-07-31) | MR 2514 (`wpa-slow-reconnect`), not merged into main as of 2026-09-24 |

Why: after resume NetworkManager has wpa_supplicant scan all channels
before it reconnects, even to the same access point, which takes several
seconds. The patch remembers the frequency in use before suspend and scans
only that one on resume; an explicit scan request gets its full scan once
the device is connected again. Io's Wi-Fi backend is wpa_supplicant, as on
SteamOS.

Applies to 1.56.0 with line offsets only (dry run against the 1.56.0 tag).
Not compiled here; the gee build is the compile test.

Way back: remove the overlay once a Void release of NetworkManager contains
the change (see overlay/README.md).
