# wpa_supplicant-holo

Replaces Void's `wpa_supplicant` (Io's default Wi-Fi backend, as on SteamOS
3.9.2).

| Patch | Source | Upstream |
|---|---|---|
| `sae-unspecified-failure-is-password-mismatch.patch` | Valve's wpa_supplicant 2:2.12-1.2 (SteamOS 3.9.2), `0001-SAE-Also-treat-UNSPECIFIED_FAILURE-as-a-password-mis.patch` (Valve task 2284) | not in hostap |
| `rescan-1-avoid-redundant-rescan.patch` | hostap `20e1762ee` (Vignesh Raman, Collabora; Valve task 1457), exported from hostap main; Valve's 2:2.12-1.3 carries the same | hostap main since 2026-10-05, no release yet (2.12 is the latest) |
| `rescan-2-dont-force-rescan.patch` | hostap `ab3200b10`, as above | as above |

Why:
- SAE (still Valve's own, not in hostap main as of 2026-10-21): some access points (hostapd before `c823197bde`, for example an ASUS
  RT-AX86U Pro) answer a wrong WPA3 password with status 15 "unspecified
  failure" instead of "challenge failure"; with the patch that counts as a
  password mismatch, so a wrong password is reported as such.
- Rescans: after resume, a regulatory change that enables 6 GHz forced a
  full rescan even when the last scan already covered 6 GHz or was
  deliberately limited to one channel. The Deck LCD's RTL8822CE has no
  6 GHz, so this matters on other hardware; carried because Valve does.

`template.append` adds wireless options that Valve's (Arch's) build
configuration enables and Void's does not: WNM (802.11v BSS transition) and
MBO, which access points use to steer a client between them (roaming with
the same network name), OCV, FILS, the learning background scan, autoscan
and 802.11be. Valve's other configuration differences stay out (among
them PC/SC and SIM/AKA authentication, which would need pcsclite; Valve's
build leaves WEP off, Void's enables it), and so do the Arch patches in
Valve's build (0001-0008: TLS 1.0 by default, no -Werror for eapol_test,
legacy renegotiation, systemd unit changes, nl80211 extra IEs, a brcmfmac
revert).

All three patches apply to the 2.12 release (Void's source) after Void's
own patch (the first rescan commit with fuzz 1 where it adds a helper
function); Void's configuration with the added options builds (checked
with the earlier, posted versions of the rescan patches).

Way back: the rescan patches go with the next hostap release Void ships;
the SAE patch when hostap takes it or Valve drops it; the options when
Void's configuration enables them. The overlay goes when all three are gone.
