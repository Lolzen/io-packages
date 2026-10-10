# Alpha 7

**Status:** in progress. What is still open is on [Milestones](Milestones).

## Changes so far

### Boot

- ***Restart* from Io starts Io again** (`io-base` 0.6.0). Io on an SD card
  has no boot entry of its own, so a restart used to start the internal
  SteamOS. A shutdown hook now sets UEFI `BootNext` to the firmware's entry
  for the card Io runs from, for the next boot only: switching the Deck off
  and on still starts SteamOS. See [Architecture](Architecture).
- **GRUB without its menu** (`io-base` 0.7.0): Io starts at once, as SteamOS
  does. The recovery stick keeps its menu.

### Image build

- The image scripts put the repository keys (Void's and Io's) into each
  root before installing, so a build whose output goes into a log no longer
  stops at xbps's question whether to import a key.

## Checked against SteamOS 3.9.2

- **`zenity`:** Void's version behaves as Valve's `zenity-gtk3`; nothing to
  port.
- **`inputattach-cec-units`:** only for Pulse-Eight and RainShadow USB-CEC
  adapters; not needed.
- **Steam's patch notes for system updates** are Valve's latest SteamOS
  notes for the update channel, on Io as well; they stay (see
  [Deviations](Deviations)).
- **The screen sharing prompt** when Steam starts in the desktop: the
  permission store looks as on SteamOS apart from the app ID, and neither
  grants it in advance. A fresh user is still to be tried.
