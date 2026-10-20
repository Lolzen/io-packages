# Helper status

Steam runs some privileged actions through helper scripts in
`/usr/bin/steamos-polkit-helpers/`, not through D-Bus. `deck-hw-support`
ships all 22 of Valve's helpers so the polkit policy stays intact; some are
stubs.

## Real

| Helper | Notes |
|---|---|
| `steamos-priv-write` | Brightness and other sysfs writes |
| `jupiter-fan-control` | Asks `io-steamos-manager` to stop or start the fan daemon |
| `steamos-disable-wireless-power-management` | Asks `io-steamos-manager`; the interface is found automatically |
| `steamos-poweroff-now`, `steamos-reboot-now` | |
| `steamos-set-hostname`, `steamos-set-timezone` | Hostname written to `/etc/hostname` and the running kernel (no `hostnamectl`); timezone through Io's `timedatectl` replacement |
| `steamos-trim-devices` | Valve's `trim-devices.sh`. SteamOS Manager's `Storage1.TrimDevices` runs the same script as a job |
| `jupiter-check-support`, `jupiter-get-als-gain` | |
| `steamos-enable-sshd` | Links the `sshd` runit service, the equivalent of Valve's `systemctl enable --now sshd` |
| `steamos-wifi-set-backend-privileged` | From `steamos-networking-tools`; switches between wpa_supplicant and iwd with runit |
| `steamos-devkit-mode` | Links (`--enable`) or removes (`--disable`) the runit services `avahi-daemon` and `steamos-devkit-service`; Steam calls it when developer mode is switched |
| `steamos-restart-sddm` | `sv restart io-sddm` (Valve: `systemctl restart sddm`); ends any session, SDDM logs in fresh |
| `steamos-update` | Valve's wrapper (re-runs itself through pkexec) around Io's `/usr/bin/steamos-update`, which answers as Valve's script with xbps behind it: `--supports-duplicate-detection` 0; `check` 0 with a build id, 7 for no update, 8 for an update waiting for a reboot (with `--enable-duplicate-detection`), 1 on errors; applying prints `atomupd-manager`'s progress lines and *Update completed*. Steam checks as `steamos-update --enable-duplicate-detection check` and reads stdout with stderr included. See [Architecture](Architecture), *System updates* |
| `steamos-select-branch` | One branch: `-c` and `-l` print `rel` (SteamOS's name for stable), `rel` and `stable` are accepted, other branches refused |
| `steamos-format-sdcard`, `steamos-format-device` | Valve's helpers (re-run through pkexec with `--owner`) and scripts: `format-sdcard.sh` and `format-device.sh` (parted, `mkfs.ext4`; `f3probe` and `mkfs.exfat` to validate a card). Io's check in `format-device.sh` refuses the disk Io runs from (tested: Steam's format of the internal SSD while Io ran from the card is refused, Steam shows *Failed to format*). Steam uses the helper, not `Storage1.FormatDevice`, which runs the same script as a job. SD cards and USB drives formatted from Steam (tested 2026-10-19), with the card check (`f3probe`) first, as on SteamOS |
| `jupiter-biosupdate` | Valve's helper: runs `steamos-firmware-update` (`deck-firmware-updaters`), which hands the Steam Deck to Valve's `jupiter-biosupdate` (BIOS images and Insyde's flasher `h2offt`). `check` exits 7 and prints `BIOS <version>` when an update is due; it only updates the BIOS versions in Valve's table. Exits 0 without `deck-firmware-updaters`. `UpdateBios1` runs `jupiter-biosupdate --auto`. `check` tested (Steam runs it after every update check; 0, as on SteamOS); updating **not tested on hardware** |
| `steamos-reset-tool` | Not a pkexec helper, but run by Steam's factory reset on SteamOS 3.9.3 (`os-status`, then `factory-reset --reset-os --reset-user-data`). Io's (`io-factory-reset`) answers as Valve's, JSON on stdout, and hands the work to `io-factory-reset`; root through polkit (`org.io.pkexec.steamos-reset-tool`: no password in the active local session) instead of Valve's setuid wrapper. Steam restarts the Deck itself. See [Deviations](Deviations), *Factory reset*. Tested (2026-10-20) |
| `steamos-factory-reset-config` | Valve's helper (re-runs itself through pkexec): requests a reset of the user data, which `io-factory-reset` carries out at the next start (Valve's records the partitions its initramfs formats). Without a password only from the active local session (Steam); Valve's policy allows any caller. See [Deviations](Deviations), *Factory reset*. Steam 3.9.3 runs `steamos-reset-tool` instead; **not tested on hardware** |
| `jupiter-dock-updater` | Dock firmware (Valve's `hub_update`). `--check` answers 7, "up to date": Valve's codes are 0 = update available, 7 = up to date, and answering 0 made Steam announce a dock update at every start. Valve's updater with the real check is on the branch `dock-fw` (pull request), to be tested with Valve's dock |

Not a helper, but also called by Steam: `jupiter-initial-firmware-update`
(Valve's script; exits at once on Jupiter).

At boot, before the login manager, `97-io-firmware-update.sh`
(`deck-firmware-updaters`) runs `jupiter-biosupdate --auto` and the
controller update with its splash, as SteamOS's
`jupiter-biosupdate.service` and `jupiter-controller-update.service` do
(log: `/var/log/io-firmware-update.log`). The controller updater does not
flash a controller whose firmware is newer than Io's copy.

## Stubs, not applicable to Io

| Helper | Why |
|---|---|
| `jupiter-amp-control` | Target script is in none of Valve's published packages and missing on SteamOS too (3.8.4 and 3.9.2); audio works without it |
| `steamos-reboot-other` | A/B slot switching |

Steam also looks for `steamos-update` and `steamos-select-branch` in
`/usr/bin`: `/usr/bin/steamos-update` is Io's script itself (from
`io-steamos-manager`), `steamos-select-branch` a symlink to the helper.
