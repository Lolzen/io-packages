# Kernel

`linux-neptune-72` is Valve's Steam Deck kernel, 7.2.4 (`7.2.4-valve1`),
built with Void's kernel packaging. SteamOS 3.8.4 runs 6.16
(`linux-neptune-616`). Io moved from 6.15.8 to Valve's 7.2 branch in
September 2026, for NTSync, the newer HID drivers and HDMI-CEC over the
dock's DisplayPort link.

---

## Source

Io does not keep a kernel fork. The package builds the kernel.org tarball
(7.2 plus `patch-7.2.4`) and applies one patch,
`patches/0001-neptune-72.patch`: the whole difference between that tree and
Valve's `linux-integration` tree at `7.2.4-valve1`, generated with
`diff -ruN` (git metadata excluded). Void's small build fixes
(`fix-ccache.patch` and the like) come on top.

The patch also carries Valve's `ci/` directory, and with it Valve's two
configuration files (see below).

---

## Configuration

`do_configure` builds the configuration in layers, each one merged over the
previous with the kernel's own `merge_config.sh`:

| Order | File | What it is |
|---|---|---|
| 1 | `files/x86_64-dotconfig` | Void's configuration for its `linux7.2` package: the base, so that every option Valve's files do not mention gets Void's value |
| 2 | `ci/kernel-config/neptune/config` (from the patch) | Valve's full configuration for this tree, about 12,500 lines, as Valve's CI builds it (generated from Arch's configuration; its header still reads 6.18.9-arch1) |
| 3 | `files/config-neptune` | Valve's Deck fragment (about 150 lines) |
| 4 | `files/config-io` | Io's own overrides, each with its reason |

`make olddefconfig` then fills in whatever the layers left open.

Until revision 3 only layers 1 and 3 were used. The result differed from
Valve's configuration in about 1,220 options — among them things SteamOS
relies on, such as `CGROUP_DMEM` and transparent huge pages set to
`always`. With Valve's full configuration in between, the comparison made
for revision 4 left 24 differences: toolchain values (compiler and
assembler versions, Rust), a number of built-in-versus-module choices, and
the overrides below.

### Io's overrides (`config-io`)

| Option | Value | Direction | Why |
|---|---|---|---|
| `LOCALVERSION_AUTO` | off | Void packaging | xbps-src sets the local version from the package revision (`_4` in `7.2.4-valve1_4`) |
| `MODULE_SIG_ALL`, `MODULE_COMPRESS_ALL` | off | Void packaging | Void's `mv-debug` splits off the debug information, then signs and compresses each module itself; doing it in `modules_install` already would be undone by the strip |
| `DEFAULT_HOSTNAME` | `(none)` | Io's own | Valve's value is Arch's (`archlinux`); the real name comes from `/etc/hostname` |
| `ANDROID_BINDER_IPC`, `ANDROID_BINDERFS` | built in | Towards SteamOS 3.8.4 | Binder for Android containers (Waydroid). SteamOS 3.8.4 has it; Valve's configuration for this tree only has the Rust variant, and Void's kernel build has no Rust toolchain |

### On every kernel update

Decided in September 2026: Void is the base, SteamOS's configuration goes on
top, and Io's own overrides come last — only where they make sense. With
each new kernel:

1. Look at each configuration on its own: Void's new base, Valve's
   `config` and `config-neptune`, and the configuration of the kernel
   SteamOS actually runs.
2. Go through `config-io` line by line.
3. Decide each difference: towards SteamOS, towards Void, or a deliberate Io
   choice. Write the reason next to the option in `config-io`, and add it to
   the table above.
4. Build, and compare the resulting `/boot/config-*` against Valve's full
   configuration before testing on the Deck.

The same rule as for all of Valve's packages applies (see
[Deviations](Deviations), *Versions*): the newer state where it makes sense,
unless the change is transitional or specific to Arch or systemd.

---

## Modules loaded at boot

Void's `modules-load` core service reads `/usr/lib/modules-load.d`, as
systemd does:

- `ntsync.conf` — NTSync (`/dev/ntsync`, for Proton), a module in Valve's
  configuration; the file is Valve's, shipped by `steamos-tuning`
- `hid-preload.conf` — `hid_nintendo` and `hid_playstation` early, so they
  claim their controllers before Steam falls back to evdev
  (`steamos-tuning`, from `steamos-customizations-jupiter`)

---

## Kernel command line

Set by `mkimg.sh`. It matches SteamOS except where [Deviations](Deviations)
(*Kernel*) says otherwise.

---

## Still to check with this kernel

- **HDMI-CEC through the dock:** the configuration is complete
  (`CEC_CORE`, `DRM_DISPLAY_HDMI_CEC_NOTIFIER_HELPER`,
  `DRM_DISPLAY_DP_AUX_CEC`); a test needs a dock that passes CEC through
- **VRAM priority for the foreground game:** `CGROUP_DMEM` is on now, as on
  SteamOS. Valve's `dmemcg-booster` uses it but depends on systemd's units
  and slices; Io would need its own way (see [Milestones](Milestones))
