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
| `steamos-trim-devices` | |
| `jupiter-check-support`, `jupiter-get-als-gain` | |
| `steamos-enable-sshd` | Links the `sshd` runit service, the equivalent of Valve's `systemctl enable --now sshd` |
| `steamos-wifi-set-backend-privileged` | From `steamos-networking-tools`; switches between wpa_supplicant and iwd with runit |
| `steamos-devkit-mode` | Links (`--enable`) or removes (`--disable`) the runit services `avahi-daemon` and `steamos-devkit-service`; Steam calls it when developer mode is switched |
| `steamos-restart-sddm` | `sv restart io-sddm` (Valve: `systemctl restart sddm`); ends any session, SDDM logs in fresh |

Not a helper, but also called by Steam: `jupiter-initial-firmware-update`
(Valve's script; exits at once on Jupiter).

## Stubs worth implementing

| Helper | Would do |
|---|---|
| `steamos-format-sdcard`, `steamos-format-device` | Formatting from Steam; needs working automount first |

## Stubs, not applicable to Io

| Helper | Why |
|---|---|
| `jupiter-amp-control` | Target script is in none of Valve's published packages and missing on SteamOS 3.8.4 too; audio works without it |
| `steamos-reboot-other` | A/B slot switching |
| `steamos-update`, `steamos-select-branch` | SteamOS system updates; `steamos-select-branch` reports `stable`. Steam is moving to a D-Bus API for updates, which Io could serve with xbps (candidate) |
| `jupiter-biosupdate` | BIOS updates, so far left to SteamOS. Valve's script needs no systemd; a check-only mode is planned for Alpha 5 |
| `jupiter-dock-updater` | Dock firmware (Valve's `hub_update`). `--check` answers 7, "up to date": Valve's codes are 0 = update available, 7 = up to date, and answering 0 made Steam announce a dock update at every start. Needs Valve's dock to port and test |
| `steamos-factory-reset-config` | Records Valve's A/B partitions for a reset; an Io reset would be its own design |

Steam also looks for `steamos-update` and `steamos-select-branch` in
`/usr/bin`, so symlinks are installed for both.
