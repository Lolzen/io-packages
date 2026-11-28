# wireplumber-holo

Replaces Void's `wireplumber`, `wireplumber-devel` and `wireplumber-elogind`.

Valve's patches from wireplumber 0.5.18-1.4 (jupiter-main, 2026-11-18):

| Patch | Source | Upstream |
|---|---|---|
| `mono-1-setting-changed-event.patch` | `0001-m-standard-event-source-push-a-setting-changed-event.patch` (Julian Bouzas, Collabora), backport of MR 942 | master `36e084d3`, not in 0.5.19 |
| `mono-2-register-reconfigured-adapters-after-activation.patch` | `0001-create-item-register-reconfigured-audio-adapters-aft.patch` (Julian Bouzas), backport of MR 943 | master (setting-changed hooks, `66d6a769`), not in 0.5.19 |

Why: Steam's *Mono audio* switch (Accessibility) sets WirePlumber's
`node.features.audio.mono` through SteamOS Manager's `Audio1`. WirePlumber
then rebuilds every audio adapter, and registered each one again as soon
as it was active: a stream could be linked before its target device was
back, found no target and was destroyed. Playing audio stopped when the
switch was toggled. With the patches a setting change is an event like the
others (mono-1), and the adapters are rebuilt in a hook for that event and
registered only once all of them are active (mono-2).

Valve's other wireplumber patches stay out: the ALSA loopback backport of
MR 667 (Io creates the loopbacks with its own script in `steamdeck-dsp`,
see Deviations, *Audio*), the external volume control setting (Valve's
own, "cannot be merged upstream", for the Steam Machine's HDMI audio) and
MR 922 (smart filters), which is in 0.5.19.

Both apply to 0.5.19 after Void's `test.patch` without fuzz (the
`wireplumber.conf` hunk with offset 1); WirePlumber builds without
warnings and its 63 tests pass (2026-11-27, against PipeWire 1.0.5 here).

`template.append`: Void's template installs PipeWire's autostart of
WirePlumber with `vsconf`, into `usr/share/examples/${pkgname}`, which for
the overlay is `wireplumber-holo`. `io-session` links
`/etc/pipewire/pipewire.conf.d/10-wireplumber.conf` to Void's path,
`usr/share/examples/wireplumber`; with 0.5.19_101 the link pointed to
nothing, PipeWire did not start WirePlumber, and game mode stayed at the
boot logo (gamescope waits for its PipeWire stream before it starts Steam;
2026-11-28). The append keeps Void's `post_install` and moves the
directory back to Void's name (0.5.19_102).

Way back: when Void ships a WirePlumber release with MR 942 and 943 (the
next one after 0.5.19; master has them since 2026-11).
