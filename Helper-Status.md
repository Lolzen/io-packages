# Helper status

`deck-hw-support` ships all 22 of Valve's polkit helpers so the policy file
stays intact, but many of them are stubs. Keeping the entries prevents polkit
actions from pointing at missing paths.

**Real:** `steamos-priv-write`, `steamos-poweroff-now`, `steamos-reboot-now`,
`jupiter-check-support`, `jupiter-get-als-gain`, `steamos-set-hostname`,
`steamos-set-timezone`, `steamos-trim-devices`,
`steamos-disable-wireless-power-management`

**Stubbed, target missing:** `jupiter-amp-control`, `steamos-reboot-other`

**Stubbed, needs systemd:** `jupiter-fan-control`, `steamos-devkit-mode`,
`steamos-enable-sshd`, `steamos-restart-sddm`

**Stubbed, dangerous or pointless here:** `jupiter-biosupdate`,
`jupiter-dock-updater`, `steamos-format-device`, `steamos-format-sdcard`,
`steamos-factory-reset-config`, `steamos-update`, `steamos-select-branch`

Steam looks for `steamos-update` and `steamos-select-branch` under `/usr/bin`,
not only in the helper directory, so symlinks are installed for both.