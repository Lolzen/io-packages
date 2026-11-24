# Beta 0.8.2 — Plasma 6.8, Valve's sparse binding

**Released:** [beta-0.8.2](https://github.com/Lolzen/io-packages/releases/tag/beta-0.8.2)

**Goal:** a catch-up release for Void's Plasma 6.8.3 with Io's patches
moved onto it, Valve's newest RADV and NetworkManager patches, and fresh
images without the packages Void removed with Plasma 6.8. What is open
afterwards is on [Milestones](Milestones).

## Highlights

- **Plasma 6.8.3** (Void's) with Io's kwin, portal and new lock screen
  overlays.
- **Lock screen keyboard:** the lock screen has its own on-screen keyboard
  again (Valve's patches for Plasma 6.8).
- **Sparse binding in one step** (Valve's RADV `steamos-26.05.20`): DX12
  games through vkd3d bind their sparse resources in one kernel call, with
  the waiting done by the kernel.
- **Wi-Fi after standby** finds other networks at once when the previous
  one is not there.

## Changes

### Desktop

- **Plasma 6.8.3** from Void. Void removed the Plasma X11 session
  (`kwin-x11`) and `kgamma` with it; Io's desktop has always been the
  Wayland session (`io-desktop.desktop`, `startplasma-wayland`), so
  nothing changes for it.
- **`kwin-holo` 6.8.3** with Valve's kwin 6.8.2-1.4: brightness from the
  panel, Steam's keyboard past the input method, and two input start-up
  fixes from kwin master (a crash at start, a lost switch state). Io's
  earlier kwin patches (libei 1.6, small modes, the suspend fixes) and
  Valve's default scale for handhelds are in 6.8.3 itself.
- **`xdg-desktop-portal-kde-holo` 6.8.3:** Steam still shares the screen
  without Plasma's dialog.
- **New `plasma-workspace-holo` and `plasma-desktop-holo`:** the lock
  screen's own Qt Virtual Keyboard, which Plasma 6.8 had replaced by
  kwin's input method (off by default on the Deck).

### Graphics

- **`mesa-holo` 26.2.7** with Valve's RADV `steamos-26.05.20` commits:
  sparse binds of a submission go to the kernel in one `AMDGPU_GEM_VA2`
  call, which waits and signals itself instead of a CPU wait. Valve's
  kernel (Io's `7.3.4-valve2`) has that call since `7.3.1-valve1`.

### Wi-Fi and session

- **`NetworkManager-holo`:** Valve's fix to the resume scan: when the
  frequency-only scan after resume misses the previous access point, the
  full scan starts at once.
- **`io-session` 0.7.8:** Steam's new session name `plasma-persistent`
  (Valve's `holo-session-selection` 1.1) starts Io's desktop.

### Valve's packages

- `jupiter-dock-updater-bin` 20261116.01: dock firmware V0.013.15.0.135
  (Valve's main branch).

## Decided

- **Kernel stays at 7.3.4 with `7.3.1-valve2`:** Valve's `7.3.1-valve3`
  (an HDMI 2.1 fix for the Steam Machine) and stable 7.3.5/7.3.6 bring
  nothing for the Deck; the next kernel comes when one does.

## Known limitations

- The Steam Deck OLED, the Steam Machine and Valve's dock are untested.
- A real BIOS or controller update is untested (only the checks and
  Valve's simulated update).
- Xwayland is 24.1.14, without the fixes of X.Org's advisory of
  2026-11-10.
- `€` (the AltGr level) from Steam's keyboard does not arrive in the
  desktop.
- Controller navigation in game mode is sometimes dead after a boot until
  the Steam button is pressed (Steam's,
  [SteamOS#2921](https://github.com/ValveSoftware/SteamOS/issues/2921)).
- During a firmware update on the Deck the Torus animation seemed hidden
  behind the logo (simulated update).
- The fan gets louder for a while after switching to the desktop (being
  looked into).
