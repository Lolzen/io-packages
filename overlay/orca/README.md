# orca-holo

Replaces Void's `orca`.

Valve's patches from orca 48.9-1.1 (SteamOS 3.9.5, holo-3.9):

| Patch | What | Upstream |
|---|---|---|
| `0001-Use-signals-to-perform-a-couple-of-actions` | SIGUSR1 reloads the settings, SIGUSR2 stops speaking (Jeremy Whiting, KDE) | not upstream; Orca 49 gives SIGUSR1 another meaning (opens the preferences) |
| `0002-Orca-Don-t-restart-speech-when-reloading-settings-vi` | no speech restart on such a reload | Valve only |
| `0003-Add-support-for-automatic-language-switching-in-docu` | automatic language switching in documents | Valve only (Igalia) |

Why: SteamOS Manager (`screenreader.rs`) sends Orca SIGUSR1 after every
change of the screen reader's settings in Steam (rate, pitch, volume,
verbosity) and SIGUSR2 for "stop talking". Without 0001 Python's default
ends Orca on either signal. SteamOS Manager then restarts it (Io's runit
support, as `orca.service`'s `Restart=on-failure`), at most five times in
ten seconds; moving a slider in Steam can exceed that and leave the screen
reader off. With the patch Orca reloads instead.

All three apply to 48.6 cleanly; the changed modules byte-compile
(2026-10-29).

Way back: when SteamOS Manager uses Orca's D-Bus interface instead of the
signals (its TODO), or Valve drops the patch. Before Void moves to Orca 49
or later, check what SIGUSR1/SIGUSR2 do there.
