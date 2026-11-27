# Kernel

`linux-neptune-73` is Io's Steam Deck kernel, built with Void's kernel
packaging: Valve's `7.3.5-valve1` (`jupiter-main`, 2026-11-26) with stable
7.3.6 merged in. SteamOS 3.9.5 runs `7.2.7-valve2`; Valve's main branch has
`7.3.5-valve1`.

The metapackage `linux-neptune` names Io's series (`linux-neptune-73`, and
`linux-neptune-headers`), as Void's `linux` does: `io-desktop` and the
recovery image depend on it, so a new series reaches installed systems
through an update. The previous series stays installed (`linux-neptune-72`,
7.2.11 with Valve's `7.2.7-valve2`): GRUB starts the newest kernel, the
older one is in GRUB's menu (hidden; Esc at boot shows it) until it is
removed by hand.

History: 6.15.8 until September 2026, then Valve's 7.2 branch (NTSync, newer
HID drivers, HDMI-CEC over the dock's DisplayPort link); 7.2.7-valve1 in
Alpha 6 and 7, 7.2.7-valve2 on stable 7.2.11 in Beta 0.8; 7.3 since
2026-11-05 as Io's own port of Valve's branch (7.3.1; 7.3.3 since
2026-11-08, 7.3.4 since 2026-11-11); Valve's `7.3.1-valve1` with 7.3.4
since 2026-11-12, `7.3.1-valve2` since 2026-11-14; `7.3.5-valve1` with
7.3.6 since 2026-11-27 (`7.3.1-valve3` with 7.3.5/7.3.6 was prepared but
not built: nothing new for the Deck).

---

## Source

Io does not keep a kernel fork. The package builds the kernel.org tarball
(7.3 plus `patch-7.3.6`) and applies one patch,
`patches/0001-neptune-73.patch`: the whole difference between stable 7.3.6
and the tree described below (without Valve's `ci/` directory and CI
files). Void's small build fixes (`fix-ccache.patch`,
`fixdep-largefile.patch`, as `linux7.3`) come on top; Void's
`fix-musl-btf-ids.patch` is upstream.

**Where Valve's tree comes from.** Valve's `linux-integration` repository
is not public, but the source archive of each `linux-neptune-*` package on
`steamdeck-packages.steamos.cloud` carries it as a bare git repository with
all of Valve's branches, not only the packaged tag. Valve's 7.3 tags come
from the archives of `linux-neptune-73` 7.3.1.valve1-1 (`jupiter-main`),
7.3.1.valve2-1 (`jupiter-3.10`) and 7.3.5.valve1-1 (`jupiter-main`),
3.4 to 3.6 GB each (Io's earlier
port came from `linux-neptune-72` 7.2.10.valve1-3, whose repository had
`7.3/integration` of 2026-11-03). The public mirror on gitlab.com (evlaV)
has no 7.x tags.

**What the tree is:**

| Part | What |
|---|---|
| Valve's `7.3.1-valve1` | 508 commits on v7.3.1: everything of `7.2.7-valve2` Valve carried over to 7.3, the merge requests of `7.2.10-valve1` (ROG Xbox Ally X20 audio, `hid-lenovo-go`, GL9767 UHS-II, `asus-armoury`, `hid-asus-ally`, rtw88's decryption checks and ASPM), the amdgpu VM explicit sync series (12 commits, with Valve's `AMDGPU_GEM_VA2` ioctl: amdgpu interface 3.66, so Mesa's `radv_vm_explicit_sync` in `mesa-holo` works again, and since 2026-11-18 its sparse binding through `AMDGPU_GEM_VA2`), 48 rtw89 and 7 mac80211/iwlwifi backports. The tag has everything Io's own port (2026-11-05 to 11-11) had |
| Stable 7.3.4 | Merged into the tag (2026-11-12). Three conflicts: `Makefile` (`SUBLEVEL` 4 with Valve's `EXTRAVERSION`); `xpad.c` (stable adds the GameSir Nova Lite as an Xbox 360 pad next to an Xbox One entry that Valve's "Remove Xbox One support" drops: the new entry kept, the Xbox One one dropped); `acp-config.c` (stable and Valve's Xbox Ally X20 commit each add an ACP 7.0 entry: both kept). Stable's own copies of Valve's `hid-lenovo-go-s`, `snd_acp63_remove()` and two rtw89 fixes merge cleanly. The generated configuration equals the port's |
| `7.3.1-valve2` | Valve's second 7.3 release (2026-11-13): the HDMI 2.1 series (VRR, FRL and ALLM over HDMI 2.1, for the Steam Machine; merge request 323) and Nouveau's atomic modesetting by default. Merged with 7.3.4 the same way; the result changes exactly the lines valve1..valve2 changes, and the generated configuration stays the same |
| `7.3.1-valve3` | 2026-11-18: one revert of the HDMI 2.1 series (merge request 324: TVs that can do FRL stayed dark in TMDS mode) |
| `7.3.5-valve1` | 2026-11-26: valve3 with stable 7.3.5, merged by Valve, and 22 commits: 18 rtw89 backports (the Steam Machine's Wi-Fi; the Deck LCD's RTL8822CE uses rtw88), ftrace dropping the weak function locations of a module when it loads (faster `modprobe` with ftrace on, merge request 326), a PAT workaround for KVM guests (merge request 317) and the release commit |
| Stable 7.3.6 | Merged into `7.3.5-valve1` by Io (2026-11-27). Four conflicts: `Makefile` (`SUBLEVEL` 6 with Valve's `EXTRAVERSION`); `net/wireless/reg.c` (stable protects the regulatory database pointer with RCU; Valve's "don't load the world regulatory domain from firmware" kept on it); rtw89's `Kconfig` (Valve's backport drops the `imply` lines as upstream does; kept); `dcn32_hwseq.c` (Valve's dcn10 shaper helper with stable's renamed `dpp`; DCN 3.2 is not the Deck's display). `btusb.c` is `btusb_main.c` in 7.3.6; Valve's changes moved with it. Three stable fixes Valve already had (FreeSync range quirk, rtw89 coexistence) merge to nothing. For every other file the merge changes what stable changes, and Valve's changes on stable are the same before and after; the merged objects compile without warnings. The generated configuration gains only stable's new `DRM_AMD_DC_DCE=y` (on by default; the same code as before) |
| `EXTRAVERSION = -valve1` | Valve's release commit sets it. The kernel release, and with it the module directory, is `7.3.6-valve1_<revision>` |

**Still not in Valve's 7.3** (of the 17 older commits Valve left out of
its branch; the 7.2 kernel is there for whoever needs them): the linear
backlight curve (see *Kernel command line*), the linearizing LUT rework,
YUV420 beyond HDMI, the HDA notify on disconnect and the dmem race fixup.
The HDMI 2.1 series came back with `7.3.1-valve2`.

Io's own port (2026-11-05 to 2026-11-12, `7.3.4-neptune1`): Valve's
`7.3/integration` (7415f40493e8, 408 commits) plus 34 commits ported from
`7.2.10-valve1`, rebased onto each stable release. Valve's tag carries the
same commits and replaced it.

---

## Configuration

`do_configure` builds the configuration in layers, each one merged over the
previous with the kernel's own `merge_config.sh`:

| Order | File | What it is |
|---|---|---|
| 1 | `files/x86_64-dotconfig` | Void's configuration for its `linux7.3` package: the base, so that every option Valve's files do not mention gets Void's value |
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
Layers 2 and 3 are Valve's files from `linux-neptune-73` 7.3.5.valve1-1 (as in 7.3.1-valve1 to valve3),
byte for byte those of `linux-neptune-72` 7.2.10.valve1 and unchanged since
7.2.7. Against Io's 7.2
configuration, 7.3 drops 20 options upstream removed (`PROC_SYSCTL` is part
of `SYSCTL` now; Open vSwitch's GRE, VXLAN and GENEVE options) and adds 88,
nearly all off; `config-io` applies unchanged. Checked for 7.2.7 (and
unchanged in 7.2.7-valve2, whose `config.x86_64` and `config-neptune` are
the same): nothing Void's userspace depends on is lost (cgroup v2
only, as runit-void uses it; zstd-compressed modules, which Void's
`mv-debug` handles; `devtmpfs` mounted by the kernel).

**Security modules:** SteamOS's order (`landlock,lockdown,yama,integrity,bpf`),
not Void's (decided 2026-10-04). TOMOYO is built but not active (not in
the list); its activation trigger is Void's `/sbin/init` instead of Arch's
systemd path (`config-io`, since 7.2.11).

**Rust:** Valve builds with Rust (the Rust Binder, a QR code on the panic
screen); Void's kernel build has no Rust toolchain, so Io builds without
it and uses the C Binder.

### Io's overrides (`config-io`)

| Option | Value | Direction | Why |
|---|---|---|---|
| `LOCALVERSION_AUTO` | off | Void packaging | xbps-src sets the local version from the package revision (`_1` in `7.3.6-valve1_1`) |
| `MODULE_SIG_ALL`, `MODULE_COMPRESS_ALL` | off | Void packaging | Void's `mv-debug` splits off the debug information, then signs and compresses each module itself; doing it in `modules_install` already would be undone by the strip |
| `DEFAULT_HOSTNAME` | `(none)` | Io's own | Valve's value is Arch's (`archlinux`); the real name comes from `/etc/hostname` |
| `ANDROID_BINDER_IPC`, `ANDROID_BINDERFS` | built in | Towards SteamOS | Binder for Android containers (Waydroid). SteamOS 3.8.4 has the C Binder, 3.9.2 the Rust Binder; Io builds without Rust, so the C one |
| `SECURITY_TOMOYO_ACTIVATION_TRIGGER` | `/sbin/init` | Towards Void | Valve's value is Arch's systemd path; Io's init is runit at `/sbin/init`. TOMOYO stays inactive either way (not in the security module list) |

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

## Old kernels

`io-base` installs a kernel hook (`/etc/kernel.d/post-install/60-io-vkpurge`)
that runs Void's `vkpurge rm all` after every kernel install: kernels no
package owns any more (the previous revision after an update) are removed
with their modules and initramfs. `vkpurge` never removes the running
kernel, so after the first boot of a new kernel the old one goes with the
next kernel install, or at once with
`sudo xbps-reconfigure -f linux-neptune-73`. A previous series is a
package of its own (`linux-neptune-72`) and stays until it is removed. Without the hook, old kernels
stayed in `/boot` until `vkpurge` was run by hand.

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

`amdgpu.dcdebugmask=0x60000`, as SteamOS since jupiter-hw-support
20261028.1: bit 0x40000 turns the firmware's custom brightness curve off,
so the brightness is linear and reaches 100 % (with the curve, Valve's
16-bit backlight levels ran past the firmware's table and stopped at about
97 %). Valve's 7.2 kernel also forced the linear curve in the driver; its
7.3 branch leaves that to this bit. Without it 7.3 logs "Using custom
brightness curve". `io-base`'s `INSTALL` changes the value Io's images
wrote (0x20000) in `/etc/default/grub` on installed systems.

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
