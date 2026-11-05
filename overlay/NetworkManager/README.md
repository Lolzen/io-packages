# NetworkManager-holo

Replaces Void's `NetworkManager`, `libnm` and `NetworkManager-devel`.

| Patch | Source | Upstream |
|---|---|---|
| `wifi-scan-only-last-associated-freq-after-resume.patch` | Valve's networkmanager 1.58.0-1.8 (SteamOS 3.9.2), `0001-wifi-supplicant-scan-only-the-last-associated-freq.patch` (Vignesh Raman, Collabora, 2026-07-31); unchanged in 1.58.0-1.9 and 1.58.1-3.2 | MR 2514 (`wpa-slow-reconnect`), not in 1.58.1 and not on main as of 2026-10-21 |
| `l3cfg-ignore-local-arp-flux-conflicts.patch` | Valve's networkmanager 1.58.1-3.2 (holo-main, 2026-11), `0001-l3cfg-ignore-local-ARP-flux-conflicts-while-defendin.patch` (Matthew Schwartz, 2026-10-28) | MR 2586, issue 1681; not on main as of 2026-11-03 |

Why: after resume NetworkManager has wpa_supplicant scan all channels
before it reconnects, even to the same access point, which takes several
seconds. The patch remembers the frequency in use before suspend and scans
only that one on resume; an explicit scan request gets its full scan once
the device is connected again. Io's Wi-Fi backend is wpa_supplicant, as on
SteamOS.

Applies to 1.58.1 without offsets (dry run against the 1.58.1 tag, after
Void's `fix-cross-gir.patch`). Not compiled here; the gee build is the
compile test.

Measured on Georg's Deck (2026-10-05, one 5 GHz network, 3 suspend cycles
each, `io-nm-resume-test.sh`): connected 1.4/1.4/1.5 s after resume with
Void's 1.56.0, 1.3/1.2/1.4 s with the overlay. Small at home; kept
(Georg's decision) for places with many networks, where the full scan
costs more, and as SteamOS does.

**ARP flux** (`l3cfg-...`): with the kernel's default `arp_ignore=0`, every
interface answers ARP for every address of the host. A Deck on Wi-Fi and on
a dock's Ethernet in the same network then sees its own Wi-Fi interface
answering for the Ethernet address; NetworkManager's address conflict
detection reports a conflict, leaves the address "not ready" and drops its
routes until the connection is activated again (SteamOS issue 2512). The
patch ignores a conflict while defending an address when the sender's MAC
belongs to another local interface that does not have the address itself;
a real duplicate is still reported, probing is unchanged.

All patches apply to 1.58.1 without offsets after Void's
`fix-cross-clat.patch` and `fix-cross-gir.patch` (checked 2026-11-05).

## Build setting (`template.append`)

`-Dpolkit_noauth_group=wheel`, as Valve builds 1.58. NetworkManager 1.58
removed the `modify_system` option, which Void set until 1.56: with it, any
active local user could create and change system-wide connections without
a password. Without it that action
(`org.freedesktop.NetworkManager.settings.modify.system`) asks for an admin
password, and game mode has no polkit agent. The option installs
`/usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules`, which
allows it for local users in `wheel`; deck is in `wheel`, not in `network`
(the group Void's own `50-org.freedesktop.NetworkManager.rules` covers).

## Not taken from Valve

- `libnm-core-allow-connecting-to-SAE-networks-with-key`: in 1.58.1, comes
  with Void's update.
- The iwd backend patches (`iwd-take-over-scanning...`,
  `wifi-iwd-fix-forget-connect`, `wifi-iwd-retry-hidden-network-activation`,
  `iwd-remove-8021X-unknown-network-restrictions`, and since 1.58.0-1.9
  `iwd-check-for-sae-network-type`, which goes with iwd 3.12-1.3's
  "report WPA3-SAE networks as sae") and the 3.8 to 3.9 migration patches
  (`iwd-mirror-wpa_supplicant-connections...`,
  `iwd-remove-IWD-profile-on-forget`): iwd is Io's second backend only.
  1.58.0-1.9 dropped `libnm-core-allow-connecting-to-SAE-networks-reported`.

Way back: remove the overlay once a Void release of NetworkManager contains
the change (see overlay/README.md). The build setting would then have to
move elsewhere (a polkit rule in an Io package) unless Void sets it.
