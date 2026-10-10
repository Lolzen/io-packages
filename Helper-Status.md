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

Not a helper, but also called by Steam: `jupiter-initial-firmware-update`
(Valve's script; exits at once on Jupiter).

## Stubs worth implementing

| Helper | Would do |
|---|---|
| `steamos-format-sdcard`, `steamos-format-device` | Formatting from Steam. Automount works and Valve's `format-device.sh` is in place, with Io's check that refuses the disk Io runs from; left for later because testing it destroys data |

## Stubs, not applicable to Io

| Helper | Why |
|---|---|
| `jupiter-amp-control` | Target script is in none of Valve's published packages and missing on SteamOS too (3.8.4 and 3.9.2); audio works without it |
| `steamos-reboot-other` | A/B slot switching |
| `jupiter-biosupdate` | BIOS updates, left to SteamOS, which runs them at boot on the same Deck. A check-only mode is deferred: it needs Valve's BIOS files and flash tool (`h2offt`) |
| `jupiter-dock-updater` | Dock firmware (Valve's `hub_update`). `--check` answers 7, "up to date": Valve's codes are 0 = update available, 7 = up to date, and answering 0 made Steam announce a dock update at every start. Needs Valve's dock to port and test |
| `steamos-factory-reset-config` | Records Valve's A/B partitions for a reset; an Io reset would be its own design |

Steam also looks for `steamos-update` and `steamos-select-branch` in
`/usr/bin`: `/usr/bin/steamos-update` is Io's script itself (from
`io-steamos-manager`), `steamos-select-branch` a symlink to the helper.
