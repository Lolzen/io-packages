# Pitfalls

Things that cost real time and are documented nowhere.

**Never start wireplumber manually.** Void configures PipeWire to launch the
session manager itself through a symlink in `/etc/pipewire/pipewire.conf.d/`.
Starting wireplumber separately creates a second instance. The symptoms are an
`auto_null` sink instead of the real devices *and* a gamescope that runs but
shows no window — with no useful error message anywhere.

**elogind must not start twice.** Void enables the runit service, but dbus also
ships an activation file with `Exec=`. At boot they race; if runit loses, it
retries every second and the session never settles. Disable the activation
file.

**acpid and elogind fight over the power button.** The Void handbook is
explicit: either disable acpid, or set every `Handle*` option in `logind.conf`
to `ignore`. Doing half of each means elogind politely ignores the button while
acpid's `handler.sh` shuts the machine down.

**Set `vk_xwayland_wait_ready=true`** before gamescope on slow storage.
Otherwise Steam starts before Xwayland is ready and none of its windows are
ever mapped.

**Never kill Steam with `pkill -9`.** It leaves state that cripples the next
start. `~/.local/share/Steam/.crash` indicates the last run ended badly. A
stale `~/.steam/steam.pipe` from an unclean shutdown can also make the *next*
`steam.sh` silently no-op: it tries to hand off to an already-running
instance via a placeholder binary that only gets real content while an
instance is actually running, fails with `ENOEXEC`, and exits 0 as if
nothing were wrong. Delete the pipe file if Steam launches and immediately
exits with no output.

**gamescope's process name is `gamescope-wl`**, not `gamescope`. Every
`pgrep -x gamescope` silently matches nothing.

**Do not update `io-session` while game mode is running.** The installed
scripts end up empty.

**inputplumber is packaged but must stay disabled.** Enabling it takes over the
`AT Translated Set 2 keyboard` and re-emits everything through a virtual
`InputPlumber Keyboard`, which breaks both `io-volumed` and
`steamos-powerbuttond`. In exchange it delivers nothing on the Deck: back
buttons already work without it, and its gyro support looks for an IIO device
that the Deck does not have. The package stays in the repo in case that
changes.

**`deck-hw-support` is frozen at 20250728.1.** From 20260807.1 onwards Valve
moved the general-purpose helpers into `holo-polkit-helpers` and renamed them
to `holo-*`. The contents are byte-identical apart from a log tag, but the
Steam client still calls the `steamos-*` names.

**`deck-hw-support`'s udev rules call `/bin/systemd-run`**, which does not
exist under runit. Every MMC event fails silently right in the boot window
`steamdeck_hwmon` needs to register, costing time it doesn't have to spare.
Replace with `setsid --fork`.

**The same rules also call `busctl` against `org.freedesktop.UDisks2`**,
which Io does not install. Even with `udisks2` added, the rule still fires
for the root/boot device itself during udev's coldplug pass in runit stage
1 — before `dbus` exists at all in stage 2 — so it will always fail or hang
for that one device regardless. Exclude the boot device explicitly, or
disable the automount rules entirely until this is worth finishing.

**`linux-neptune`'s `do_install` deliberately deletes its own bundled
`/usr/lib/firmware`**, with a comment saying it's "provided by the
linux-firmware pkg." Nothing pulled that in by default — `linux-neptune`
needs an explicit `depends="linux-firmware-amd linux-firmware-network"`, or
the Deck boots with a dead GPU and no WiFi/Bluetooth firmware, silently.

**Steam's 32-bit bootstrapper needs `libcurl-32bit`.** Without it every
update check fails with a generic `http error 0` that reads like a network
problem but isn't.

**`seatd` needs the user in the `_seatd` group**, not just
`wheel,audio,video,input,storage`. Without it `libseat` gets `Permission
denied` on the socket and gamescope silently falls back to a headless
backend — no crash, just a black screen with an otherwise normal-looking
log.

**A package's `post_install()` template function is a *build-time* hook
only** — it runs during `xbps-src pkg <name>`, operating on the real build
host, not the package's destdir. It never runs on the target system at
`xbps-install` time. Code that needs to run when the package is actually
installed belongs in a real `INSTALL` file (`srcpkgs/<pkg>/INSTALL`, using
`$ACTION`), not a template function.

**`xbps-install -r` run before `/proc`, `/dev`, `/sys` are bind-mounted
leaves any package's `INSTALL` script silently deferred**, not executed —
xbps can't chroot to run it without a working `/proc`. If package
installation happens before your bind mounts in an image-building script,
follow up with `xbps-reconfigure -a` once they're in place.

**Steam's bootstrapper needs an actual network connection**, not just on
first install but after every client update — a fully offline first boot
fails with a misleading "needs to be online" error rather than retrying
gracefully.

**A silent `growpart` resize is a real risk, not just a UX gap.** It runs as
a runit core-service in boot stage 1, blocking all of stage 2 (nothing else
starts) until it finishes, with zero on-screen indication anything is
happening. Powering off mid-`resize2fs` on the root filesystem is exactly
the kind of interruption that can corrupt the card.

**`post_extract` is not run** in templates without a `build_style`. Put the
checkout step at the start of `do_install` instead.

**The CS35L41 needs two firmware files** that are not in Void's
`linux-firmware`: `cs35l41-dsp1-spk-prot.wmfw` and
`cs35l41-dsp1-spk-prot-vlv1776.bin` from `linux-firmware-neptune`. Without them
one speaker stays silent. No mixer gymnastics are needed beyond that —
wireplumber handles channel assignment through the UCM profile.

**`force_drivers+=" amdgpu "` in the dracut config is mandatory.** Without the
module in the initramfs the screen stays black through early KMS.

**`python_version=3` is required** in any template shipping a Python script,
or the shebang rewrite hook aborts the build.

**Valve's `python<3.14` constraints were too conservative** and have since been
relaxed upstream to `>=3.14`.

**`steamos-priv-write` needs two edits** for Void: `chgrp deck` becomes
`chgrp wheel` (matching Valve's own polkit rule, which checks group membership
in `wheel`), and `systemd-cat` becomes `logger`.

**Rust packages do not need Arch's vendored crate lists.** `build_style=cargo`
resolves crates.io dependencies itself, including git dependencies pinned by
revision. What it does need is `clang`, `llvm` and `clang21-devel` in the build
dependencies — the versioned `-devel` package is the only one shipping the
unversioned `libclang.so` symlink that `clang-sys` looks for.

**PAM capabilities (`pam_cap`) do not survive Io's autologin path.**
`session optional pam_cap.so` correctly populates the inheritable set on the
login process, but a plain `setuid()` to an unprivileged user (as Void's
`login` does when switching to `deck`) clears all capability sets unless the
code explicitly keeps them — Void's `login` doesn't. A file capability
(`setcap`) on gamescope itself is worse, not better: it puts the binary into
secure-execution mode, which makes `ld.so` drop `LD_PRELOAD`, breaking
Steam's screenshot/recording overlay injection. The correct fix (matching
what Valve does with `AmbientCapabilities=`) is a root-started wrapper that
sets an ambient capability and changes to `deck` in one controlled step —
not a PAM session hook, and not a one-line `setcap`.# Pitfalls

**A warm reboot (`reboot`, including Steam's own restart menu entry) can
boot into a completely different OS, not just fail to restart Io cleanly.**
On a dual-boot setup where Io lives on a removable SD card (`--removable`
GRUB install, no NVRAM entry — necessary since the card's partition GUIDs
change on every rebuild) alongside an internal drive with its own
registered NVRAM default, a warm reboot skips the boot-selector screen
entirely and goes straight to the firmware's stored default — which is
whatever owns NVRAM, not necessarily the card you just booted from. Looks
identical to a broken service from inside the session (network still
connects, but SSH refuses and nothing in Io's own service list explains
why) until you actually look at the console and see a different OS's
login prompt.

**A PipeWire module's `.conf` filename can collide with an unrelated PipeWire
concept of the same name.** `libpipewire-module-filter-chain` is meant to be
loaded as a fragment in `pipewire.conf.d/`, joining the already-running main
session. But PipeWire *also* ships its own standalone `filter-chain.conf`
base config, meant to be run as `pipewire -c filter-chain.conf` — a
completely separate, standalone server with its own new `pipewire-0`
socket. Naming a fragment directory `filter-chain.conf.d/` (as Valve's
source does) makes it easy to load the fragment as if it were that
standalone config instead of a `pipewire.conf.d/` addition — it will load
without error, produce a node that looks correct in isolation, and connect
to nothing in the real session. Always install PipeWire module fragments
into `pipewire.conf.d/`, never a directory that shares a name with one of
PipeWire's own top-level configs.

**`exec` inside a script that's `.`-sourced (not executed) takes down
everything after it, not just itself.** Void's `/etc/runit/1` reads each
`core-services/*.sh` file with `. "$f"` in a loop, not by running it as its
own process. A `core-services` script that ends in `exec some-binary`
replaces runit's own stage-1 process with that binary — once the binary
exits, runit treats stage 1 as finished and moves on to stage 2, silently
skipping every remaining script in the loop (in our case, several actual
system-init steps got skipped this way, boot looked completely normal
regardless). Use a plain call, not `exec`, in anything sourced into another
script's process.

**A `libpipewire-module-loopback` bound to a `target.object` at session
start can bind to nothing and never retry.** If the target node (in our
case, an ALSA capture node WirePlumber hadn't enumerated yet) doesn't exist
the moment PipeWire loads the module, the loopback comes up fully formed —
correct properties, correct priority, no error anywhere — but is connected
to nothing, and stays that way permanently; nothing about it will indicate
the problem short of manually confirming a live capture through it. Fix by
setting `target.delay.sec` (module option, since PipeWire 0.3.60) high
enough to guarantee the target already exists — a plain resource-startup
race, not a bug in the target itself. A quicker but misleading way to
"confirm" the fix is working is checking `wpctl status`/`pw-dump`: an idle,
correctly-bound loopback and a permanently-broken one look identical there
in both cases (both report `"state": "suspended"` with no visible link) —
only an actual read/write against the node (e.g. `pw-record`, checking the
resulting file size isn't just an empty header) tells them apart.

**WirePlumber's `node.create-loopback=true` property (set by
`alsa-loopback.conf`, meant to auto-hide raw ALSA sources behind a
higher-priority loopback) silently does nothing on wireplumber 0.5.17,
despite being present and working in the exact same file on real SteamOS's
0.5.14.** Confirmed this isn't a Valve patch — the reactive code (function
`CreateLoopback` in `monitors/alsa.lua`) is present unmodified in real
SteamOS's own pristine, unpatched `alsa.lua.orig`, so it's an upstream
WirePlumber change/removal somewhere between those two versions, not
something Valve added. Diffing SteamOS's patched vs. unpatched `alsa.lua`
is a good way to separate genuine Valve patches from stock upstream
behavior when chasing something like this — most of what looks
Valve-specific in a diff often isn't. Worked around with a plain,
hand-built `libpipewire-module-loopback` instead of relying on this
property (see the `target.delay.sec` entry above for what that needed).

**A rename-then-source udev/init script can lose its executable bit on the
renamed file.** A `mv script script.orig` + replacement-wrapper pattern
(used for the growpart boot-notice wrapper) left `script.orig` non-executable
after a package rebuild — the wrapper's call to it failed with "Permission
denied" while the wrapper's own "done" message still printed, making the
failure invisible unless you go looking. Confirm the moved file's mode
explicitly after any such rename, don't assume `mv` always preserves it in
every packaging context.

**A `here-doc`'d config file can end up truncated by one line with no
error at the point of writing.** A `sudo tee file << 'EOF' ... EOF` copy-paste
silently lost its closing bracket line once — `tee` and the shell reported
no error, the file was simply short by exactly the content that would have
closed the outermost block. PipeWire's own config parser caught it cleanly
(`Mismatched bracket`, with a line/column), but only in its own startup log,
which nothing else surfaces — a config that fails to parse this way doesn't
throw an error anywhere else, the module and everything it would have
provided is just silently absent. `wc -l` against the file right after
writing it is a fast, cheap sanity check worth doing by habit for anything
written via heredoc.

**PipeWire/ALSA "probe_volumes: Path X is not a volume or mute control"
warnings are not a config bug and not fixable from a device-specific
package.** They come from `alsa-card-profile`'s generic, PulseAudio-derived
mixer-path files (`/usr/share/alsa-card-profile/mixer/paths/*.conf`) —
written to cover many different sound cards' worth of possible mixer
elements at once, they probe for `volume` support on elements that, on this
particular hardware, are pure on/off switches. The warning is the expected,
harmless result of a broad compatibility layer meeting one specific card;
patching it out would mean patching shared, generic system files used by
every other sound card on the system too, for a purely cosmetic log line.

**`/etc/sysctl.d` is rejected by Void's own package linter.** A package
installing files there fails at `pre-pkg` with "is forbidden. Use
/usr/lib/sysctl.d." — `/etc` is reserved for the user's own overrides,
packages ship their defaults under `/usr/lib/sysctl.d` instead, which the
user can then shadow from `/etc/sysctl.d` if they want to override a
specific value.

**`vcopy` doesn't create its destination directory, unlike `vinstall`/`vbin`.**
Copying a whole directory tree with `vcopy src dst` fails with "cannot
create directory" if `dst`'s parent doesn't already exist in the
destination — needs an explicit `vmkdir` for the parent path first.