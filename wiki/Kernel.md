# Kernel

`linux-neptune-72` is Valve's Steam Deck kernel, 7.2.7 (`7.2.7-valve1`,
since Alpha 6), built with Void's kernel packaging; SteamOS 3.9.2 runs the
same version. SteamOS 3.8.4 ran 6.16 (`linux-neptune-616`). Io moved from 6.15.8 to Valve's 7.2 branch in
September 2026, for NTSync, the newer HID drivers and HDMI-CEC over the
dock's DisplayPort link.

---

## Source

Io does not keep a kernel fork. The package builds the kernel.org tarball
(7.2 plus `patch-7.2.7`) and applies one patch,
`patches/0001-neptune-72.patch`: the whole difference between that tree and
Valve's `linux-integration` tree at `7.2.7-valve1` (generated from Valve's
mirror, without Valve's `ci/` directory and CI files; applied, it gives
Valve's tree). Void's small build fixes (`fix-ccache.patch` and the like)
come on top. `fix-musl-btf-ids.patch` is gone: upstream since 7.2.4.

---

## Configuration

`do_configure` builds the configuration in layers, each one merged over the
previous with the kernel's own `merge_config.sh`:

| Order | File | What it is |
|---|---|---|
| 1 | `files/x86_64-dotconfig` | Void's configuration for its `linux7.2` package: the base, so that every option Valve's files do not mention gets Void's value |
| 2 | `files/config.x86_64` | The full configuration Valve's `linux-neptune-72` package builds from (Arch's, shipped next to Valve's PKGBUILD) |
| 3 | `files/config-neptune` | Valve's Deck fragment (about 150 lines), merged over it as Valve's PKGBUILD does |
| 4 | `files/config-io` | Io's own overrides, each with its reason |

`make olddefconfig` then fills in whatever the layers left open.

Layer 2 was Valve's in-tree CI configuration (`ci/kernel-config/neptune/config`)
until Alpha 6. Valve's package does not build from it, and Io's kernel
differed from Valve's build in 132 options, among them transparent huge
pages for shmem and tmpfs (`never` instead of SteamOS's `advise`). With
`config.x86_64` 9 differences remain (compared without Rust on either
side): the overrides of `config-io`, and two drivers Void's base switches
on (Surface RT, Arctic fan). Before that (until
revision 3 of 7.2.4) only layers 1 and 3 were used, about 1,220 options
apart from Valve's.

Since Valve's configuration is a full one, it overrides nearly every option
Void's base sets; Void's value survives only where it has no entry.
Checked for 7.2.7: nothing Void's userspace depends on is lost (cgroup v2
only, as runit-void uses it; zstd-compressed modules, which Void's
`mv-debug` handles; `devtmpfs` mounted by the kernel).

**Security modules:** SteamOS's order (`landlock,lockdown,yama,integrity,bpf`),
not Void's (decided 2026-10-04). TOMOYO is built but not active; its
activation trigger is still Arch's systemd path and follows Void's
`/sbin/init` with the next kernel update.

**Rust:** Valve builds with Rust (the Rust Binder, a QR code on the panic
screen); Void's kernel build has no Rust toolchain, so Io builds without
it and uses the C Binder.

### Io's overrides (`config-io`)

| Option | Value | Direction | Why |
|---|---|---|---|
| `LOCALVERSION_AUTO` | off | Void packaging | xbps-src sets the local version from the package revision (`_1` in `7.2.7-valve1_1`) |
| `MODULE_SIG_ALL`, `MODULE_COMPRESS_ALL` | off | Void packaging | Void's `mv-debug` splits off the debug information, then signs and compresses each module itself; doing it in `modules_install` already would be undone by the strip |
| `DEFAULT_HOSTNAME` | `(none)` | Io's own | Valve's value is Arch's (`archlinux`); the real name comes from `/etc/hostname` |
| `ANDROID_BINDER_IPC`, `ANDROID_BINDERFS` | built in | Towards SteamOS | Binder for Android containers (Waydroid). SteamOS 3.8.4 has the C Binder, 3.9.2 the Rust Binder; Io builds without Rust, so the C one |

### On every kernel update

Decided in September 2026: Void is the base, SteamOS's configuration goes on
top, and Io's own overrides come last — only where they make sense. With
each new kernel:

1. Look at each configuration on its own: Void's new base, Valve's
   `config.x86_64` and `config-neptune` (next to Valve's PKGBUILD), and the
   configuration of the kernel SteamOS actually runs.
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

Set by the image build (`build/mkrootfs.sh`, GRUB's defaults). It matches SteamOS except where [Deviations](Deviations)
(*Kernel*) says otherwise.

---

## Still to check with this kernel

- **HDMI-CEC through the dock:** the configuration is complete
  (`CEC_CORE`, `DRM_DISPLAY_HDMI_CEC_NOTIFIER_HELPER`,
  `DRM_DISPLAY_DP_AUX_CEC`); a test needs a dock that passes CEC through
- **Wake-on-Bluetooth:** Valve's patch for the LCD's Realtek controller is
  in, and dmesg says `wake-on-bluetooth enabled` with Void's firmware as
  well as with Valve's (version `0x3d7679d7`, in place since Alpha 6
  through `deck-firmware`). Whether a controller really wakes the Deck is
  untested

`CGROUP_DMEM` is on, as on SteamOS; Valve's `dmemcg-booster` that uses it
is not ported (decided, see [Deviations](Deviations)).
