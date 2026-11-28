# mesa-holo

Replaces Void's `mesa` and all its subpackages (`mesa-dri`,
`mesa-vulkan-radeon`, `mesa-vaapi`, `libgbm`, ...), and, as the first
overlay with `lib32=yes`, their `-32bit` packages as well
(`mesa-dri-holo-32bit`, ...). holo.sh renames every subpackage and the
template's own `subpackages=` list; nothing is written by hand.

SteamOS 3.9.2 builds Mesa from two sources: OpenGL from `radeonsi-26.1.2`
(Mesa 26.1.2 plus one Valve commit) and Vulkan (RADV) from
`steamos-26.05.19` (a Mesa main snapshot of May 2026 plus backports and
Valve's own commits); Valve's main and 3.10 branches have RADV
`steamos-26.05.20` since 2026-11-17. Void's 26.2.8 is newer than both, so
only Valve's own commits are taken over: the `STEAMOS:` commits (checked
against Valve's `jupiter-3.9` sources of 2026-10-15) and the six commits
of `steamos-26.05.20` (2026-11-16), which have no prefix but exist only in
Valve's tree, for the kernel interface of Valve's kernel, with the two
fixes for them from `steamos-26.05.22` (2026-11-25).
The three RADV fixes from Mesa main that Io carried for 26.2.5
(descriptor set allocator heap size, memory leak and error code when a pool
entry fails) are in 26.2.6.

| Patch | What | Upstream |
|---|---|---|
| 0001 | **OpenGL frame limiter:** with gamescope's `GAMESCOPE_LIMITER_FILE`, DRI3 (OpenGL under Xwayland) follows Steam's frame limit | Valve only |
| 0002 | Forza Horizon 5: at least 4 swapchain images (`vk_x11_override_min_image_count`), else the game can get stuck in low clocks with gamescope's vblank reservation | Valve only |
| 0003, 0004 | `amdgpu_drm.h` synced with the kernel, `AMDGPU_VM_EXPLICIT_SYNC` | uapi in Valve's kernel (Io's `linux-neptune-72`; `linux-neptune-73` since Valve's 7.3.1-valve1, whose explicit sync series Valve's 7.3 branch had left out) |
| 0005-0009 | **Explicit synchronisation for VM operations** (sparse binding without implicit sync), behind the driconf option `radv_vm_explicit_sync`; since 0017-0020 sparse binds use `AMDGPU_GEM_VA2` instead | Valve only |
| 0010, 0011 | `radv_vm_explicit_sync` for Forza Horizon 4, 5 and 6 (stutter) | Valve only |
| 0012 | `VK_EXT_pageable_device_local_memory` (memory priorities for DXVK and vkd3d-proton); a no-op on kernels without Valve's ioctl | Valve only |
| 0013, 0014 | **Per command buffer BO tracking, and no global BO list for gamescope:** a buffer shared by gamescope and the game made the kernel synchronise both processes' submissions (GPU bubbles, stutter in game mode). Valve's device check keeps the global list when gamescope enables a feature that needs it | Valve only (holo-team/tasks#2011) |
| 0015 | `amdgpu_drm.h` synced again: `AMDGPU_GEM_VA2` (0x1B, a batch of mappings with syncobj waits and signals) and `AMDGPU_PROC_OPTIONS` (0x1A), identical to the kernel's header | uapi in Valve's kernel (`[FOR-UPSTREAM]`, amdgpu interface 3.66; in `linux-neptune-73` since `7.3.1-valve1`) |
| 0016 | Explicit synchronisation for VM operations from amdgpu 3.66 on (was 3.65: upstream's 3.65 is a different feature, which Valve's kernel skips) | Valve only |
| 0017-0020 | **Sparse binding in one ioctl:** RADV collects a submission's sparse binds and hands them to the kernel with `AMDGPU_GEM_VA2`, with the submission's semaphores as kernel-side waits and signals, instead of one ioctl per bind after a CPU wait. Active whenever the kernel has amdgpu 3.66 (not tied to `radv_vm_explicit_sync`); other kernels keep the old path (one ioctl per bind after a CPU wait). With it the `AMDGPU_VM_EXPLICIT_SYNC` path of 0005-0009 goes: `radv_vm_explicit_sync` now only keeps 0006's wait for an idle queue before old preambles are freed | Valve only |
| 0021, 0022 | Fixes for 0019 (Matthew Schwartz): when a sparse range is unbound on a GPU with the null PRT bug (GFX10 to GFX12 except GFX9, so the Deck), each mapping of RADV's 8 MiB zero buffer now has the size of its chunk instead of the whole range (a range over 8 MiB made the `AMDGPU_GEM_VA2` ioctl fail with `-EINVAL`) and the same page flags as the old path (it was mapped without access flags) | Valve only |

Rebased onto 26.2.5 by Io (noted in each patch): 0008 (calls changed
upstream, sync type moved out of the winsys), 0009 and 0014 (RADV's driconf
options are declared in `radv_drirc_gen.py` there), 0013 (small conflicts).
Compile-tested (RADV and radeonsi, x86_64) before committing. All 14 apply
to 26.2.6 unchanged, without fuzz, and compile (RADV and radeonsi, x86_64,
2026-10-29); the same for 26.2.7 after Void's musl patches (2026-11-13;
of the 28 files the patches touch, 26.2.7 changed `ac_gpu_info.c`, CU
count per shader array, and `radv_cmd_buffer.c`, conditional rendering,
both away from the patched lines).

0015-0020 apply to 26.2.7 after 0001-0014 without fuzz and compile (RADV,
x86_64, 2026-11-18; the structs in 0015 compared with the kernel's
`include/uapi/drm/amdgpu_drm.h` of `7.3.1-valve3`). Valve's
`ac_drm_bo_va2_op_raw()` call in 0019 passes the full wait and signal
counts although the arrays skip dummy syncs; kept as Valve has it.
0021 and 0022 apply after them with offset 1, without fuzz, and RADV
compiles (2026-11-25). Valve's `jupiter-3.9` reverted 0015-0020 on
2026-11-24 (`steamos-26.05.21.1`, stable branch); its main took these two
fixes instead, and Io follows main.

Void's 26.2.8 (2026-11-28): all 22 apply after Void's patches without fuzz
(the same offsets as on 26.2.7; Void's musl hunk in
`radv_amdgpu_winsys.h` needs fuzz there as before). Of the files the
patches touch, 26.2.8 changes `radv_cmd_buffer.c` (push constant stages
for compute and ray tracing) and `00-radv-defaults.conf` (a World of
Warcraft entry), both away from the patched lines. RADV, radeonsi and
`loader_dri3_helper.c` compile (x86_64; the one warning in
`loader_dri3_helper.c`, an unchecked `pread()`, is in Valve's 0001).

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
