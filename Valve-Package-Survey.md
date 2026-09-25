# Valve package survey

935 packages across jupiter-main and holo-main, filtered down to 80 with
SteamOS-specific naming. Snapshot as of September 2026 — Valve adds and
renames packages over time, worth re-running before acting on this list.

## Done since this survey

`steamdeck-dsp`, `holo-zram-swap`, `holo-earlyoom`, `holo-dmi-rules`,
`steam-jupiter-stable` (as `steam-jupiter`), `vpower` with
`holo-upower-config`, `steamdeck-kde-presets`, `steam-im-modules`, and
Void's `mangohud` and `gamemode` set up as on SteamOS (see
[Packages](Packages)). `holo-grant-cap-sys-nice` is no longer needed:
the reference capture showed SteamOS gives gamescope `CAP_SYS_NICE` as a
plain file capability, which Io now does too.

## Smaller, probably worth it

`steamos-systemreport` and `steamos-networking-tools` are ported (Alpha 4).
`holo-realtek-firmware-toggles`, `jupiter-firewall` and
`jupiter-validation-tools` are small items for later (see
[Milestones](Milestones))

## Deliberate direction, not a straight port

- `steamos-log-submitter` / `jupiter-steamos-log-submitter` — keep for
  completeness, but retarget so nothing phones home to Valve
- `steamos-reset` — port only if not Arch-specific and Io can carry the
  needed adaptations safely

## Not relevant right now

- `steamos-atomupd-client`, `steamos-efi`, `steamos-repair-backend`/`-tool-git`,
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
  implements. The other half of the package (`holo.conf`) is SDDM
  configuration; Io runs SDDM since Alpha 4 with its own
  (`io-session`)
- `steamos-alias` — a pacman/libalpm hook mechanism (auto-creates
  `steamos-*` symlinks for `holo-*` files on install/remove). No xbps
  equivalent. The rename it covers arrived with `jupiter-hw-support`
  20260807.1; Io keeps the `steamos-*` names instead, as SteamOS 3.8.4 and
  Steam still use them
- `jupiter-legacy-support` — upstream's own `PKGBUILD` header says it best:
  "Everything still in here should be either removed or re-homed to a
  proper package." A grab-bag of QA/devkit tooling, Valve's own workarounds
  for their broken `/var/boot` mechanics, and other cruft even Valve wants
  gone. Two pieces were looked at: `KillUserProcesses=True` — with SDDM,
  session switches are real logouts now, so it is worth another look (see
  [Milestones](Milestones)); `steam-web-debug-portforward` (CEF debugging
  in developer mode) is a small item for later
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

## Deprioritized for now, parked deliberately

Not pursued in this pass on purpose — low expected value, or needs
something Io doesn't have yet. Revisit if the underlying gap closes
(e.g. NVMe migration, desktop-mode maturity) or on request:

- `jupiter-dock-updater-bin` — needs Valve's own official dock hardware
- `steamos-devkit-service` — only relevant for the Steamworks devkit
  developer workflow
- `steamos-kdumpst-layer` — kernel crash-dump tooling, developer-facing
- `NetworkManager/conf.d/10-steamos-defaults.conf` — parked deliberately; tied
  to the open Wi-Fi backend decision (SteamOS defaults to iwd, Io uses
  wpa_supplicant)

## Kernel bump follow-ups (linux-neptune-72, Sept 2026)

Three items motivated the 6.15.8 → 7.2.4 bump in the first place; the bump
itself is done and verified, but none of these three has actually been
checked against the new kernel yet:

- `ntsync` — confirmed working: `CONFIG_NTSYNC=y`, `/dev/ntsync` exists
  with correct permissions, no changes needed
- `hid_nintendo`/`hid_playstation` — confirmed working: both built as
  modules (`hid-nintendo.ko.zst`, `hid-playstation.ko.zst`), correctly
  installed, no changes needed
- HDMI-CEC — Kconfig-complete (`CEC_CORE`, `DRM_DISPLAY_HDMI_CEC_NOTIFIER_HELPER`,
  `DRM_DISPLAY_DP_AUX_CEC` all correct for the Deck's USB-C/DP-AUX dock
  path). Functional test with real dock hardware still pending — own
  follow-up session

**Trackpad swipe haptics** (the fine texture under a finger swiping across a
trackpad) were suspected to have regressed with the kernel bump. Current
SteamOS lacks them as well, so this is a change in the Steam client, not a
kernel or Io issue. (`CONFIG_HID_HAPTIC`, once considered for it, was never
actually part of the 7.2 build.)
