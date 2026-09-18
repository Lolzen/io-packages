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

## Everything else, unreviewed

`holo-flatpak-tmpfiles`, `holo-nfs-utils-tmpfiles`, `holo-fstab-repair`,
`holo-plymouth-config`, `holo-plymouth-themes`, `holo-debuginfod-config`,
`holo-rust-packaging-tools`, `holo-session-selection`,
`steamos-kdumpst-layer`, `steamos-passwd`, `steamos-tweak-mtu-probing`,
`steamos-alias`, `steamos-devkit-service`, `jupiter-dock-updater-bin`,
`jupiter-legacy-support`, `jupiter-resolved-nomdns`,
`steamos-customizations-git`, `steamos-customizations-jupiter`

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