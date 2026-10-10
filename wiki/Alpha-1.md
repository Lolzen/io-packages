# Alpha 1 — First bootable image

**Released:** [alpha1](https://github.com/Lolzen/io-packages/releases/tag/alpha1)

**Goal:** a bootable Void Linux image for the Steam Deck LCD that lands in
Steam's game mode, plays games, and can switch to the desktop and back.

## Highlights

- Boots from an SD card straight into Steam's game mode
- Games run, including Proton
- Switching to a desktop session and back

## Known limitations at release

- TDP and charge limit menus in the Steam client not verified
- `CAP_SYS_NICE` for gamescope not set (no realtime priority, not a
  functional blocker)
- udisks2 automount disabled (package not installed)
- Root partition grown silently in the background on first boot
- Desktop session (Plasma) untested
