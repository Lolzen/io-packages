# MangoHud-holo

Replaces Void's `MangoHud` and `MangoHud-mangoapp` (`MangoHud-32bit` stays
Void's).

| Patch | Source | Upstream |
|---|---|---|
| `mangoapp-throttle-one-render-per-frame.patch` | MangoHud `2c1dc52` (2026-06-06), "mangoapp: throttle overlay to one render per game frame"; carried by Valve's mangohud 0.8.3.rc1.r24.g33c2c7dd-4 (SteamOS 3.9.2) | master only, after v0.8.4 |

Why: `a3b5683` (in v0.8.3 and v0.8.4, so in Void's 0.8.4) removed the wait
in mangoapp's main loop; since then mangoapp renders the performance overlay
on every loop iteration instead of once per game frame (MangoHud issue 2060).
gamescope does not pace external overlays, so this costs GPU time and lets
games overshoot their frame limit. Applies to v0.8.4 unchanged (checked
against Void's source archive, same checksum as Void's template).

Way back: when Void ships a MangoHud release that contains `2c1dc52`
(expected 0.8.5), remove this overlay and switch `io-desktop` back to
`MangoHud` and `MangoHud-mangoapp`; an Io package must then replace
`MangoHud-holo` and `MangoHud-mangoapp-holo`, or the Deck keeps them.
