# xdg-desktop-portal-kde-holo

Replaces Void's `xdg-desktop-portal-kde`.

| Patch | Source | Upstream |
|---|---|---|
| `screencast-1-steam-without-prompt.patch` | Valve's xdg-desktop-portal-kde 6.7.3-1.2 (SteamOS 3.9.3, holo-main), `0001-Skip-authentication-checks-for-Steam-in-the-screenca.patch` (Arjen Hiemstra, 2026-06-04) | not upstream (Valve: "to be documented") |
| `screencast-2-steam-by-caller.patch` | Io | Io only (needed without systemd) |

Why:
- Steam asks the screen cast portal for the screen when it starts in the
  desktop (persist mode 2, with its restore token). Without saved restore
  data Plasma shows its *Share screen with* dialog; Valve's patch shares all
  screens with Steam without asking, as on SteamOS.
- Valve's patch matches the app id `steam`, which xdg-desktop-portal takes
  from the caller's systemd user unit (`app-steam@….service` on SteamOS).
  Void builds xdg-desktop-portal without systemd, so on Io every host
  application has an empty app id (captured 2026-10-29: Steam's
  `CreateSession`, `SelectSources` and `Start` all reached the backend with
  `""`). The second patch recognises Steam by the caller instead: the
  request handle carries the sender's unique bus name, the session bus
  gives its process, and its executable must be Steam's client
  (`steamrt64/steam`, or `ubuntu12_32/steam` of the 32-bit client). Only
  for an empty app id; a real app id still decides as in Valve's patch.

Trust: as with Valve's check, a program that names itself like Steam's
client gets the screen without a prompt; on SteamOS a program started under
a systemd unit named for Steam does. Host programs are not sandboxed either
way.

Steam's saved choice wins: with valid restore data (a choice made in the
dialog earlier, with *Allow restoring*) the portal restores that choice and
the patches do not apply.

Both apply to 6.7.5 in this order.

Way back: when Valve's patch is upstream, the first goes; the second stays
as long as xdg-desktop-portal gives host applications no id without
systemd, unless Steam registers its id with the portal's host registry.
