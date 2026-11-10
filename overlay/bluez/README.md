# bluez-holo

Replaces Void's `bluez`, `libbluetooth` and the other bluez subpackages.

| Patch | Source | Upstream |
|---|---|---|
| `adapter-fix-le-add-device-to-resolving-list.patch` | Valve's bluez 5.86-4.1 and 5.87-2.4 (SteamOS 3.9.2; 5.87-2.5 in holo-3.10 is a rebuild with the same patches), `0001-BlueZ-adapter-Fix-execute-LE-Add-Device-To-Resolving.patch` (Clancy Shang, 2024) | posted to linux-bluetooth, not merged (not in 5.88) |
| `input-switch-pro-controller-no-forced-active-mode.patch` | Valve's bluez 5.87-2.4 and 2.5, `0024-Modify-Nintendo-gamepad-abnormal-disconnect-during-use.patch` | not sent upstream (Valve's note; not in 5.88) |

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

Valve's other bluez patches stay out: the main.conf settings are Io's own
configuration (io-base, /usr/share/io/bluetooth/main.conf); the wake-policy
plugin and LL privacy are no-ops on 3.9.2; the rest are test or CI changes.

Both apply to 5.88 (same source archive as Void's, checked 2026-11-10)
after Void's own patches, with line offsets and no fuzz. Test build with
Void's configure options, GCC 13 with `-std=gnu2x` and GCC 14's default errors
(int-conversion, incompatible pointer types): no errors. Void's 5.88
carries `c23-return-null.patch`, so Io's `-std=gnu17` workaround for
5.86 (`template.append`) is gone; without that patch the same build
fails in `src/shared/ad.c` and `tools/mesh/mesh-db.c` as before.
