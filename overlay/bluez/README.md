# bluez-holo

Replaces Void's `bluez`, `libbluetooth` and the other bluez subpackages.

| Patch | Source | Upstream |
|---|---|---|
| `adapter-fix-le-add-device-to-resolving-list.patch` | Valve's bluez 5.86-4.1 and 5.87-2.4 (SteamOS 3.9.2), `0001-BlueZ-adapter-Fix-execute-LE-Add-Device-To-Resolving.patch` (Clancy Shang, 2024) | posted to linux-bluetooth, not merged (not in 5.87) |
| `input-switch-pro-controller-no-forced-active-mode.patch` | Valve's bluez 5.87-2.4, `0024-Modify-Nintendo-gamepad-abnormal-disconnect-during-use.patch` | not sent upstream (Valve's note) |

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

- C23 build (`template.append`: `CFLAGS="-std=gnu17"`): Void's autoconf
  2.73 makes configure prefer C23, and the `autoreconf` in Void's template
  regenerates it, so bluez 5.86 is compiled with `-std=gnu23`. There
  `false` is no longer a null pointer constant, and bluez returns it from
  pointer functions in several places (src/shared/ad.c, tools/mesh). Void's
  own bluez template fails the same way on a current Void (its 5.86_2
  package was built before). `-std=gnu17` is what GCC 14 uses by default,
  i.e. how bluez was built until now. Drop it once bluez or Void fix this.

Valve's other bluez patches stay out: the main.conf settings are Io's own
configuration (io-base, /usr/share/io/bluetooth/main.conf); the wake-policy
plugin and LL privacy are no-ops on 3.9.2; the rest are test or CI changes.

Both apply to 5.86 (same source archive as Void's) after Void's own
patches; test build with Void's configure options, a C23 compiler and
`-std=gnu17`: no errors.
