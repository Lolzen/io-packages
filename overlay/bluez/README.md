# bluez-holo

Replaces Void's `bluez`, `libbluetooth` and the other bluez subpackages.

| Patch | Source | Upstream |
|---|---|---|
| `adapter-fix-le-add-device-to-resolving-list.patch` | Valve's bluez 5.86-4.1 and 5.87-2.4 (SteamOS 3.9.2), `0001-BlueZ-adapter-Fix-execute-LE-Add-Device-To-Resolving.patch` (Clancy Shang, 2024) | posted to linux-bluetooth, not merged (not in 5.87) |
| `input-switch-pro-controller-no-forced-active-mode.patch` | Valve's bluez 5.87-2.4, `0024-Modify-Nintendo-gamepad-abnormal-disconnect-during-use.patch` | not sent upstream (Valve's note) |
| `shared-ad-fix-c23-build.patch` | Io: `bt_ad_has_data` returns `NULL` instead of `false` | unfixed in master |

Why:
- Resolving list: when a device is paired again under a new address,
  bluetoothd kept the old stored device with the same identity key (IRK).
  The controller then rejects "LE Add Device To Resolving List" for the
  duplicate key (spec: Invalid HCI Command Parameters), which per Valve's
  note could block a suspend request with the Steam Controller (Valve task
  1267). With the patch, bluetoothd removes the stored device that has the
  same IRK before it stores the new one.
- Switch Pro Controller (057e:2009): its HID interrupt channel is set to
  BT_POWER_FORCE_ACTIVE_OFF, so the link may use sniff mode; Valve's fix for
  unstable connections and disconnects during use (tasks 2268, 2287).

- C23 build: Void's autoconf 2.73 makes configure prefer C23, and the
  `autoreconf` in Void's template regenerates it, so bluez 5.86 builds with
  `-std=gnu23`, where `false` is no longer a null pointer. Void's own bluez
  template fails the same way on a current Void (its 5.86_2 package was
  built before). Found when gee built bluez-holo for the first time.

Valve's other bluez patches stay out: the main.conf settings are Io's own
configuration (io-base, /usr/share/io/bluetooth/main.conf); the wake-policy
plugin and LL privacy are no-ops on 3.9.2; the rest are test or CI changes.

All three apply to 5.86 (same source archive as Void's) after Void's own
patches; bluez 5.86 with them builds in C23 mode (test build, gcc 13
-std=gnu2x).
