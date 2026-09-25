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
| `steamos-set-hostname`, `steamos-set-timezone` | Timezone through Io's `timedatectl` replacement |
| `steamos-trim-devices` | |
| `jupiter-check-support`, `jupiter-get-als-gain` | |
| `steamos-enable-sshd` | Links the `sshd` runit service, the equivalent of Valve's `systemctl enable --now sshd` |
| `steamos-wifi-set-backend-privileged` | From `steamos-networking-tools`; switches between wpa_supplicant and iwd with runit |

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
| `jupiter-biosupdate`, `jupiter-dock-updater` | Firmware updates, so far left to SteamOS. Valve's scripts need no systemd; a check-only mode is planned for the end of Alpha 4 |
| `steamos-factory-reset-config` | Records Valve's A/B partitions for a reset; an Io reset would be its own design |
| `steamos-devkit-mode` | Steamworks devkit workflow; `steamos-devkit-service` could be ported with Avahi |
| `steamos-restart-sddm` | Io has no display manager |

Steam also looks for `steamos-update` and `steamos-select-branch` in
`/usr/bin`, so symlinks are installed for both.
