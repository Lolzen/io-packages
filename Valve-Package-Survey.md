# Valve package survey

935 packages across jupiter-main and holo-main, filtered down to 80 with
SteamOS-specific naming. Snapshot as of September 2026 — Valve adds and
renames packages over time, worth re-running before acting on this list.

## Worth a look soon

- `holo-grant-cap-sys-nice` — may already solve the CAP_SYS_NICE-for-gamescope
  problem (root-started wrapper vs. PAM session, see Pitfalls) instead of us
  building our own
- `steamdeck-dsp` — possible source for the `jupiter-amp-control` stub target
- `holo-zram-swap`, `holo-earlyoom` — memory pressure handling on a
  memory-constrained handheld
- `holo-upower-config` — battery reporting tuning
- `steamdeck-kde-presets` — better Plasma defaults for the desktop-mode side

## Smaller, probably worth it

`holo-dmi-rules`, `holo-realtek-firmware-toggles`, `jupiter-firewall`,
`steamos-efi`, `steamos-systemreport`, `jupiter-validation-tools`

## Deliberate direction, not a straight port

- `steamos-log-submitter` / `jupiter-steamos-log-submitter` — keep for
  completeness, but retarget so nothing phones home to Valve
- `steamos-reset` — port only if not Arch-specific and Io can carry the
  needed adaptations safely

## Not relevant right now

- `steamos-atomupd-client`, `steamos-repair-backend`/`-tool-git`,
  `steamos-media-creation-git` — all tied to the A/B update system Io
  doesn't have. Revisit if/when Io gets its own A/B update mechanism
  (GitHub Releases or similar free hosting) — a 1.0-level goal, not Beta
- `steamos-manager` (Valve's real, Rust one) — superseded by `io-steamos-manager`
- `holo-keyring` — pacman/Arch signing, irrelevant to xbps

## Guiding principle

Fewer dead stubs is good, but never at the cost of Io's own stability or
security. Most of this is "adapt", not "copy" — Beta-phase work, not a
rush now.

## A/B mechanics, found while reading steamos-customizations-jupiter (Sept 2026)

Not catalogued individually before — the specific pieces behind the atomic
A/B system, found while browsing this package's full source tree:

- `atomic-update/` — RAUC integration, `steamos-atomupd` client hookup,
  systemd units, tmpfiles rules
- `chainloader/` — GRUB-level slot switching between A/B partition sets
- `initrd/holo-etc-overlay.ash` — mounts `/etc` as a writable overlay on
  top of the read-only root, at initramfs time, before anything else runs
- `initrd/holo-factory-reset.ash`, `initrd/holo-var.ash`,
  `initrd/holo-var-lib-modules.ash` — factory reset and `/var`/module
  overlay handling, same initramfs stage

`holo-fstab-repair` (ported, see Packages) is a small, concrete example of
what changes once `/etc` is atomic: upstream's systemd unit only exists
because SteamOS's `/etc/fstab` gets reset from a golden image on every A/B
update, so the repair has to re-run every boot. Io's port dropped that
condition since Io's `/etc` is plain and persistent - revisit this
specific package's condition (and the general assumption "Io's /etc never
resets itself") if Io ever gets its own atomic /etc overlay.

`grub/grub.d/30_efi-prober.in` — also A/B-specific, no memory-file entry
needed (self-explanatory once you see it): probes removable media only
(`isremovable`) for `EFI/steamos/steamcl.efi`, SteamOS's own
installer/recovery chainloader. Nothing to port; not something Io's normal
boot path needs.

# Full triage of the "unreviewed" list (Sept 2026)

Everything that was in "Everything else, unreviewed" got worked through.
Outcomes below — packages now ported are in [Packages](Packages), not
repeated here.

**Ported:** `steamos-tweak-mtu-probing`, `holo-fstab-repair` (folded into
`steamos-tuning`/its own package respectively — see Packages)

**Nothing to port, with reason:**
- `holo-session-selection` — the actual session-switch script
  (`holo-session-select`) is itself marked deprecated upstream in favour of
  `steamosctl`, which is exactly what Io's own `io-steamos-manager` already
  implements. The other half of the package (`holo.conf`) is pure SDDM
  config — Io has no display manager
- `steamos-alias` — a pacman/libalpm hook mechanism (auto-creates
  `steamos-*` symlinks for `holo-*` files on install/remove). No xbps
  equivalent, and the underlying problem it solves — a historical
  `steamos`→`holo` rename needing back-compat symlinks — never happened on
  Io in the first place
- `jupiter-legacy-support` — upstream's own `PKGBUILD` header says it best:
  "Everything still in here should be either removed or re-homed to a
  proper package." A grab-bag of QA/devkit tooling, Valve's own workarounds
  for their broken `/var/boot` mechanics, and other cruft even Valve wants
  gone
- `jupiter-resolved-nomdns` — `systemd-resolved`-specific (Io uses
  NetworkManager directly), and exists only to stop mDNS colliding with
  `avahi`, which is only there for `steamos-devkit-service` — a chain of
  two things Io doesn't have
- `steamos-customizations-git` — a stale, unmaintained snapshot of the same
  repo as `steamos-customizations-jupiter` (frozen since 2023-09, confirmed
  by comparing tag histories); superseded by `-jupiter`, nothing to look at
  independently
- `holo-nfs-utils-tmpfiles`, `holo-debuginfod-config`,
  `holo-rust-packaging-tools` — never actually opened; no plausible Io use
  case (no NFS setup, debug-symbol server convenience for developers,
  Arch-specific build tooling `xbps-src` doesn't use)

**`steamos-customizations-jupiter` itself** (the actively maintained one,
`jupiter-main`) is a large, still-growing repo (tags up to the day before
this survey). Reviewed folder-by-folder:
- `misc/` — the useful part, source of `steamos-tuning`/`holo-fstab-repair`
  above. `sysctl.d`, `limits.d`, `sleep.conf.d` (suspend-then-hibernate,
  not yet looked at), `modules-load.d/ntsync.conf` (needs the kernel bump
  to 7.2, see the kernel-bump note elsewhere) still have unreviewed pieces
- `atomic-update/`, `chainloader/`, most of `initrd/` — A/B mechanics, see
  the dedicated section above
- `swap/`, `grub/`, `NetworkManager/`, `offload/` — not opened yet

## Deprioritized for now ("Stufe 4/5"), parked deliberately

Not pursued in this pass on purpose — low expected value, or needs
something Io doesn't have yet. Revisit if the underlying gap closes
(e.g. NVMe migration, desktop-mode maturity) or on request:

- `jupiter-dock-updater-bin` — needs Valve's own official dock hardware
- `steamos-devkit-service` — only relevant for the Steamworks devkit
  developer workflow
- `steamos-kdumpst-layer` — kernel crash-dump tooling, developer-facing
- `NetworkManager/conf.d/10-steamos-defaults.conf` — parked deliberately,
see holovoid memory notes: this is a hardening/polish item, not something
worth doing mid-development.

## Kernel bump follow-ups (linux-neptune-72, Sept 2026)

Three items motivated the 6.15.8 → 7.2.4 bump in the first place; the bump
itself is done and verified, but none of these three has actually been
checked against the new kernel yet:

- `ntsync` — mainlined since Linux 6.14, needs a Kconfig check in
  `config-neptune`/`config-io`, then `modinfo ntsync` on the Deck
- `hid_nintendo`/`hid_playstation` — external Switch Pro/DualSense
  controller support, needed for Steam to prefer `hidraw` over `evdev`
- HDMI-CEC — relevant for docking to a TV

**New, unrelated to the above:** trackpad swipe haptics (the fine texture
under a finger swiping across a trackpad — not tap, not controller rumble)
regressed between 6.15.8 and 7.2.4. Controller force feedback itself works
fine (`CONFIG_STEAM_FF=y`, confirmed via `ff_memless` and the `EV_FF` bit
on the Deck's emulated Xbox 360 pad). No Kconfig option covers it — nothing
touchpad/trackpad-related exists in `drivers/hid/Kconfig` beyond the
generic, unrelated `HID_HAPTIC`. Points to a real source-level change in
`hid-steam.c` between Valve's two kernel branches; needs a direct diff of
that one file between the `0001-neptune.patch` (6.15.8) and
`0001-neptune-72.patch` (7.2.4) patch sets to find the actual change.