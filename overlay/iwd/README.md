# iwd-holo

Replaces Void's `iwd`. iwd is Io's second Wi-Fi backend, switched in Steam
(SteamOS Manager's `WifiBackend1`), as on SteamOS.

| Patch | Source | Upstream |
|---|---|---|
| `station-1-avoid-flushing-bss-cache.patch` | Valve's iwd 3.12-1.2 (SteamOS 3.9.2), `0001-station-avoid-flushing-BSS-cache-on-partial-channel-.patch` (Valve task 1978) | not in iwd |
| `station-2-protect-pending-bss.patch` | same, `0002-station-protect-pending-BSS-during-connection-attemp.patch` | not in iwd |
| `station-3-cancel-scans-before-connecting.patch` | same, `0001-station-Cancel-scans-before-connecting.patch` | not in iwd |
| `station-4-only-scan-supported-bands.patch` | Valve's iwd 3.12-1.21 (SteamOS 3.9.3), `0001-station-only-scan-bands-supported-by-the-adapter.patch` (Valve task 1019, "should be sent upstream") | not in iwd |

Why: a scan of only some channels no longer empties the list of known
access points, the access point being connected to is not dropped from it
during the attempt, a pending scan no longer blocks a new connection, and
scans only cover the bands the adapter supports (the kernel rejected a scan
that included 2.4 GHz on an adapter without it).

Named so that holo.sh applies them in Valve's order; all four apply to
3.12 (Void's source, same checksum as Valve's) after Void's patches.
Valve's `use-network-group` diff is Arch's packaging, not Valve's, and stays out.

Way back: drop them when they are in an iwd release Void ships.
