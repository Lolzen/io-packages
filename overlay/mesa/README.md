# mesa-holo

Replaces Void's `mesa` and all its subpackages (`mesa-dri`,
`mesa-vulkan-radeon`, `mesa-vaapi`, `libgbm`, ...), and, as the first
overlay with `lib32=yes`, their `-32bit` packages as well
(`mesa-dri-holo-32bit`, ...). holo.sh renames every subpackage and the
template's own `subpackages=` list; nothing is written by hand.

SteamOS 3.9.2 builds Mesa from two sources: OpenGL from `radeonsi-26.1.2`
(Mesa 26.1.2 plus one Valve commit) and Vulkan (RADV) from
`steamos-26.05.19` (a Mesa main snapshot of May 2026 plus backports and
Valve's own commits). Void's 26.2.6 is newer than both, so only Valve's own
commits (`STEAMOS:`) are taken over (checked against Valve's `jupiter-3.9`
sources of 2026-10-15; no newer RADV snapshot on Valve's mirror on
2026-10-29). The three RADV fixes from Mesa main that Io carried for 26.2.5
(descriptor set allocator heap size, memory leak and error code when a pool
entry fails) are in 26.2.6.

| Patch | What | Upstream |
|---|---|---|
| 0001 | **OpenGL frame limiter:** with gamescope's `GAMESCOPE_LIMITER_FILE`, DRI3 (OpenGL under Xwayland) follows Steam's frame limit | Valve only |
| 0002 | Forza Horizon 5: at least 4 swapchain images (`vk_x11_override_min_image_count`), else the game can get stuck in low clocks with gamescope's vblank reservation | Valve only |
| 0003, 0004 | `amdgpu_drm.h` synced with the kernel, `AMDGPU_VM_EXPLICIT_SYNC` | uapi in Valve's kernel (Io's `linux-neptune-72`) |
| 0005-0009 | **Explicit synchronisation for VM operations** (sparse binding without implicit sync), behind the driconf option `radv_vm_explicit_sync` | Valve only |
| 0010, 0011 | `radv_vm_explicit_sync` for Forza Horizon 4, 5 and 6 (stutter) | Valve only |
| 0012 | `VK_EXT_pageable_device_local_memory` (memory priorities for DXVK and vkd3d-proton); a no-op on kernels without Valve's ioctl | Valve only |
| 0013, 0014 | **Per command buffer BO tracking, and no global BO list for gamescope:** a buffer shared by gamescope and the game made the kernel synchronise both processes' submissions (GPU bubbles, stutter in game mode). Valve's device check keeps the global list when gamescope enables a feature that needs it | Valve only (holo-team/tasks#2011) |

Rebased onto 26.2.5 by Io (noted in each patch): 0008 (calls changed
upstream, sync type moved out of the winsys), 0009 and 0014 (RADV's driconf
options are declared in `radv_drirc_gen.py` there), 0013 (small conflicts).
Compile-tested (RADV and radeonsi, x86_64) before committing. All 14 apply
to 26.2.6 unchanged, without fuzz, and compile (RADV and radeonsi, x86_64,
2026-10-29).

Left out: Valve's `radv: always consider some outputs as invariant` (in
26.2.5 already), CI expectation files and Valve's pick script.

Way back: per patch, when Void's Mesa contains it. When the overlay goes, switch `io-desktop` and `steam-jupiter`
back to Void's names; an Io package must then replace the `-holo` and
`-holo-32bit` packages.

If gamescope ever misbehaves with 0013/0014, the global BO list comes back
for it with a drirc override, without a rebuild:

```xml
<driconf><device><application name="Gamescope" application_name_match="gamescope">
<option name="radv_disable_global_bo_list" value="false"/>
</application></device></driconf>
```

in `~/.drirc` of the user gamescope runs as.
