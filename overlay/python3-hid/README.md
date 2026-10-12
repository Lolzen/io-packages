# python3-hid-holo

Replaces Void's `python3-hid` (pyhidapi, the ctypes bindings to hidapi).

| Patch | Source | Upstream |
|---|---|---|
| `pyhidapi-1.0.6.patch` | pyhidapi's changes from 1.0.4 to 1.0.6 in `hid/__init__.py` (PyPI's 1.0.6): `BusType` and the `bus_type` field of the device info (hidapi 0.13 and later), `get_input_report`; Valve's jupiter-hw-support requires `python-hid>=1.0.6-2` | released in 1.0.5 and 1.0.6; Void ships 1.0.4 |

Why: Valve's controller firmware updater (`deck-firmware-updaters`,
`d21bootloader16.py getdevicesjson`, used for the check before every
update) reads `hid.BusType`, which pyhidapi 1.0.4 does not have. Void's
hidapi is 0.14, so the `bus_type` field is there. Checked against Void's
source (pyhidapi's 1.0.4 tag): applies, and the result is PyPI's 1.0.6
`hid/__init__.py`.

Way back: when Void ships python3-hid 1.0.6 or later, remove this overlay
and switch `deck-firmware-updaters` back to `python3-hid`.
