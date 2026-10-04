#!/usr/bin/python3
"""io-steamos-manager: Io's reimplementation of Valve's steamos-manager.

Same split as the original (confirmed by a capture on real SteamOS 3.8.4):

  io-steamos-manager -r   root daemon on the SYSTEM bus. Owns
                          com.steampowered.SteamOSManager1 there and exports
                          only the RootManager interface. It is the only
                          part that writes to sysfs or controls services.
                          Runs as a runit service.

  io-steamos-manager      user daemon on the SESSION bus. Exports the
                          interfaces Steam talks to, reads current values
                          straight from sysfs (all world-readable) and
                          forwards every write to the root daemon.
                          Started by io-gamemode and, in Plasma, via XDG
                          autostart - like Valve's user unit, which is
                          wanted by graphical-session.target.

No pkexec, no io-priv-exec. The root daemon validates every value itself;
access to it is limited by its D-Bus policy.

Values and interface sets follow the capture (Steam Deck LCD, "Jupiter"):
TdpLimit 3..15 W, GPU power profiles CAPPED/UNCAPPED only, desktop session
"plasma.desktop", no PerformanceProfile1. Setters report the value that is
actually in effect afterwards, read back from sysfs, not the requested one.

Storage1 runs Valve's scripts as jobs, as steamos-manager does: the root
daemon starts the process and exports it as a Job1 object on the system
bus, the user daemon mirrors that object on the session bus (JobManager1
announces it). TrimDevices is real; FormatDevice is refused until
formatting is ported and tested.

Not implemented (Io lacks the backing pieces): UdevEvents1, UpdateBios1,
UpdateDock1, FactoryReset1.
"""

import asyncio
import glob
import signal
import json
import os
import re
import subprocess
import sys
import time

from dbus_fast import BusType, Message, MessageType, PropertyAccess, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.errors import DBusError
from dbus_fast.service import ServiceInterface, dbus_property, method
from dbus_fast.service import signal as dbus_signal

BUSNAME = "com.steampowered.SteamOSManager1"
OBJPATH = "/com/steampowered/SteamOSManager1"
IFACE = "com.steampowered.SteamOSManager1"
ROOT_IFACE = f"{IFACE}.RootManager"
ERR = f"{IFACE}.Error.Failed"

STATE_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")

# From Valve's /usr/share/steamos-manager/devices/steam-deck.toml
TDP_MIN = 3
TDP_MAX = 15
GPU_POWER_PROFILES = ("CAPPED", "UNCAPPED")
# Sessions SDDM logs into (io-session). Steam and Valve's
# steamos-session-select name Plasma's session files; Io has one desktop
# session, which stands for all of them.
GAME_SESSION = "gamescope-wayland.desktop"
DESKTOP_SESSION = "io-desktop.desktop"
DESKTOP_ALIASES = (DESKTOP_SESSION, "plasma.desktop", "plasmax11.desktop")
# As steamos-manager: the default login mode, and a one-shot session for
# the next login only.
SDDM_DEFAULT = "/etc/sddm.conf.d/zz-steamos-autologin.conf"
SDDM_TEMP = "/etc/sddm.conf.d/zzt-steamos-temp-login.conf"


def log(msg):
    print(f"io-steamos-manager: {msg}", file=sys.stderr, flush=True)


# ------------------------------------------------------------ sysfs paths

def _read_file(path, default=""):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return default


def _hwmon(name=None, attr=None):
    """hwmon directory by driver name and/or by having a given attribute."""
    for d in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        if name and _read_file(f"{d}/name") != name:
            continue
        if attr and not os.path.exists(f"{d}/{attr}"):
            continue
        return d
    return None


def _gpu_dev():
    for d in sorted(glob.glob("/sys/class/drm/card*/device")):
        if os.path.exists(f"{d}/power_dpm_force_performance_level"):
            return d
    return None


def _wifi_iface():
    for d in sorted(glob.glob("/sys/class/net/*/wireless")):
        return os.path.basename(os.path.dirname(d))
    return None


def _board():
    return _read_file("/sys/class/dmi/id/board_name", "unknown")


def _int(text, default=0):
    try:
        return int(text)
    except (TypeError, ValueError):
        return default


# -------------------------------------------------------------- readers

def read_tdp():
    d = _hwmon("amdgpu", "power1_cap")
    return _int(_read_file(f"{d}/power1_cap"), TDP_MAX * 1000000) // 1000000 if d else TDP_MAX


def read_charge_level():
    d = _hwmon(attr="max_battery_charge_level")
    value = _int(_read_file(f"{d}/max_battery_charge_level")) if d else 0
    return value if value > 0 else -1


def read_gpu_level():
    d = _gpu_dev()
    return _read_file(f"{d}/power_dpm_force_performance_level", "auto") if d else "auto"


def read_od():
    """(current, min, max) of the manual GPU clock from pp_od_clk_voltage."""
    d = _gpu_dev()
    text = _read_file(f"{d}/pp_od_clk_voltage") if d else ""
    current, lo, hi = None, 200, 1600
    section = ""
    for line in text.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0].endswith(":") and not parts[0][:-1].isdigit():
            section = parts[0]
        if section == "OD_SCLK:" and parts[0] == "0:" and len(parts) > 1:
            current = _int(parts[1].lower().replace("mhz", ""), None)
        if parts[0] == "SCLK:" and len(parts) >= 3:
            lo = _int(parts[1].lower().replace("mhz", ""), lo)
            hi = _int(parts[2].lower().replace("mhz", ""), hi)
    return (current if current is not None else lo), lo, hi


def read_power_profiles():
    """{NAME: index} from pp_power_profile_mode, plus the active name."""
    d = _gpu_dev()
    text = _read_file(f"{d}/pp_power_profile_mode") if d else ""
    profiles, active = {}, None
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].isdigit():
            name = parts[1].strip("*:").upper()
            profiles[name] = int(parts[0])
            if "*" in parts[1]:
                active = name
    return profiles, active


def read_governors():
    avail = _read_file(
        "/sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors")
    current = _read_file("/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")
    return avail.split(), current


def read_boost():
    return 1 if _int(_read_file("/sys/devices/system/cpu/cpufreq/boost", "1"), 1) else 0


def read_fan_state():
    out = subprocess.run(["pgrep", "-f", "fancontrol.py --run"],
                         capture_output=True, check=False)
    return 1 if out.returncode == 0 else 0


def read_wifi_powersave():
    ifname = _wifi_iface()
    if not ifname:
        return 0
    out = subprocess.run(["iw", "dev", ifname, "get", "power_save"],
                         capture_output=True, text=True, check=False)
    return 1 if "on" in out.stdout.lower() else 0


# Valve keeps wifi.powersave in 99-valve-wifi-backend.conf, which
# steamos-wifi-set-backend rewrites when switching (dropping the setting).
# Io keeps it in a file of its own.
WIFI_POWERSAVE_CONF = "/etc/NetworkManager/conf.d/99-io-wifi-powersave.conf"
# NetworkManager only applies wifi.powersave through wpa_supplicant; iwd
# takes it from its own configuration and has no config fragments.
IWD_MAIN_CONF = "/etc/iwd/main.conf"


def _write_iwd_powersave(enabled):
    """Power save off for iwd: [DriverQuirks] PowerSaveDisable=* in
    main.conf; on: the key removed (iwd then keeps the kernel's default,
    which is on). Edited line by line, so comments and every other setting
    in the file stay as they were written."""
    try:
        with open(IWD_MAIN_CONF) as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        lines = []
    out = []
    section = None
    header = None
    written = False
    for line in lines:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1].strip()
            if section == "DriverQuirks":
                header = len(out)
            out.append(line)
            continue
        if section == "DriverQuirks" and s.split("=", 1)[0].strip() == "PowerSaveDisable":
            if not enabled and not written:
                out.append("PowerSaveDisable=*")
                written = True
            continue
        out.append(line)
    if not enabled and not written:
        if header is not None:
            out.insert(header + 1, "PowerSaveDisable=*")
        else:
            if out and out[-1].strip():
                out.append("")
            out += ["[DriverQuirks]", "PowerSaveDisable=*"]
    if enabled and header is not None:
        # Drop the section header if nothing but blank lines is left under it.
        nxt = next((i for i in range(header + 1, len(out))
                    if out[i].strip().startswith("[")), len(out))
        if not any(l.strip() for l in out[header + 1:nxt]):
            del out[header:nxt]
    if not any(l.strip() for l in out):
        if os.path.exists(IWD_MAIN_CONF):
            os.remove(IWD_MAIN_CONF)
        return
    os.makedirs(os.path.dirname(IWD_MAIN_CONF), exist_ok=True)
    with open(IWD_MAIN_CONF, "w") as f:
        f.write("\n".join(out) + "\n")


def read_wifi_backend():
    """Last wifi.backend= setting in NetworkManager's config, like NM itself
    resolves it (conf.d files in name order override NetworkManager.conf)."""
    files = ["/etc/NetworkManager/NetworkManager.conf"]
    files += sorted(glob.glob("/usr/lib/NetworkManager/conf.d/*.conf"))
    files += sorted(glob.glob("/etc/NetworkManager/conf.d/*.conf"))
    backend = "wpa_supplicant"
    for path in files:
        for line in _read_file(path).splitlines():
            line = line.strip()
            if line.startswith("wifi.backend="):
                backend = line.split("=", 1)[1].strip()
    return backend


# ================================================================== ROOT

def _write(path, value):
    with open(path, "w", encoding="utf-8") as f:
        f.write(str(value))


# sched_ext: SteamOS offers none and lavd (scx_lavd from scx-scheds, started
# by scx.service with /etc/default/scx). Io's runit service does the same.
SCX_SERVICE_DIR = "/etc/sv/scx"
SCX_SERVICE_LINK = "/var/service/scx"


def available_cpu_schedulers():
    if os.access("/usr/bin/scx_lavd", os.X_OK):
        return ["none", "lavd"]
    return ["none"]


def _fail(msg):
    log(msg)
    raise DBusError(ERR, msg)


# ================================================================== JOBS
# As steamos-manager (job.rs): a job is one process; Pause and Resume send
# SIGSTOP and SIGCONT, Cancel SIGTERM (SIGKILL with force), Wait resumes a
# paused job and returns the exit code, or the negative signal number.

JOB_PREFIX = f"{OBJPATH}/Jobs"
JOB_IFACE = f"{IFACE}.Job1"
JOBMANAGER_IFACE = f"{IFACE}.JobManager1"
NOT_SUPPORTED = "org.freedesktop.DBus.Error.NotSupported"
# Valve's platform.toml: [storage.trim_devices]
TRIM_SCRIPT = "/usr/lib/hwsupport/trim-devices.sh"


class JobManager1(ServiceInterface):
    """Lives at .../Jobs and announces every new job."""

    def __init__(self):
        super().__init__(JOBMANAGER_IFACE)

    @dbus_signal()
    def JobStarted(self, job) -> "o":
        return job


class Job1(ServiceInterface):
    """Root side: one running process."""

    def __init__(self, proc):
        super().__init__(JOB_IFACE)
        self.proc = proc
        self.paused = False

    def _signal(self, sig):
        if self.proc.returncode is not None:
            _fail("the job has already finished")
        try:
            os.kill(self.proc.pid, sig)
        except ProcessLookupError:
            pass  # it ended in the meantime

    @method()
    def Pause(self):
        if self.paused:
            _fail("Already paused")
        self._signal(signal.SIGSTOP)
        self.paused = True

    @method()
    def Resume(self):
        if not self.paused:
            _fail("Not paused")
        self._signal(signal.SIGCONT)
        self.paused = False

    @method()
    def Cancel(self, force: "b"):
        if self.proc.returncode is None:
            self._signal(signal.SIGKILL if force else signal.SIGTERM)
            if self.paused and self.proc.returncode is None:
                self._signal(signal.SIGCONT)
            self.paused = False

    @method()
    async def Wait(self) -> "i":
        if self.paused and self.proc.returncode is None:
            self._signal(signal.SIGCONT)
            self.paused = False
        # asyncio reports a death by signal N as -N, as steamos-manager does
        return await self.proc.wait()

    @method()
    def ExitCode(self) -> "i":
        if self.proc.returncode is None:
            _fail("the job is still running")
        return self.proc.returncode


class Jobs:
    """Starts processes as jobs and exports them on one bus. The root daemon
    numbers its jobs from its start time, so a job path the user daemon still
    holds from before a root restart cannot name a new job."""

    def __init__(self, bus, first=0):
        self.bus = bus
        self.manager = JobManager1()
        self.next = first
        bus.export(JOB_PREFIX, self.manager)

    def add(self, iface):
        path = f"{JOB_PREFIX}/{self.next}"
        self.next += 1
        self.bus.export(path, iface)
        self.manager.JobStarted(path)
        return path

    async def run(self, argv, what):
        try:
            proc = await asyncio.create_subprocess_exec(*argv, stdin=subprocess.DEVNULL)
        except OSError as err:
            _fail(f"{what}: {err}")
        log(f"job {self.next}: {what} (pid {proc.pid})")
        return self.add(Job1(proc))


class RootManager(ServiceInterface):
    """Privileged half. Every method validates its input against the
    hardware's own limits before touching sysfs."""

    def __init__(self, jobs=None):
        super().__init__(ROOT_IFACE)
        self.jobs = jobs

    @method()
    async def TrimDevices(self) -> "o":
        return await self.jobs.run([TRIM_SCRIPT], "trimming devices")

    @method()
    def FormatDevice(self, device: "s", label: "s", validate: "b") -> "o":
        # Formatting is destructive and not ported yet (Alpha 5): refused
        # the way steamos-manager refuses it on a platform without it.
        log(f"FormatDevice {device} refused: not available on Io yet")
        raise DBusError(NOT_SUPPORTED, "FormatDevice is not available on Io yet")

    @method()
    def ReloadConfig(self):
        pass

    @method()
    def SetTdpLimit(self, limit: "u"):
        if not TDP_MIN <= limit <= TDP_MAX:
            _fail(f"TDP {limit} W outside {TDP_MIN}..{TDP_MAX}")
        d = _hwmon("amdgpu", "power1_cap")
        if not d:
            _fail("no amdgpu power1_cap")
        # sustained and fast PPT limit: steamos-manager writes the same value
        # to both (power.rs, set_tdp_limit; v26.1.0 on SteamOS 3.8.4, v26.4.1 on 3.9.2)
        for attr in ("power1_cap", "power2_cap"):
            if os.path.exists(f"{d}/{attr}"):
                _write(f"{d}/{attr}", limit * 1000000)

    @method()
    def SetGpuPerformanceLevel(self, level: "s"):
        if level not in ("auto", "low", "high", "manual", "profile_peak"):
            _fail(f"invalid GPU performance level {level}")
        d = _gpu_dev()
        if not d:
            _fail("no amdgpu device")
        _write(f"{d}/power_dpm_force_performance_level", level)

    @method()
    def SetManualGpuClock(self, clocks: "u"):
        _, lo, hi = read_od()
        if not lo <= clocks <= hi:
            _fail(f"GPU clock {clocks} outside {lo}..{hi}")
        # As steamos-manager (gpu.rs, set_clocks): write the clock and leave
        # the performance level alone. The kernel takes it only in manual
        # mode and answers EINVAL otherwise, which goes back to Steam as an
        # error, as on SteamOS (Steam sets the clock at every start, also in
        # auto mode).
        od = f"{_gpu_dev()}/pp_od_clk_voltage"
        try:
            _write(od, f"s 0 {clocks}")
            _write(od, f"s 1 {clocks}")
            _write(od, "c")
        except OSError as err:
            _fail(f"Error setting manual GPU clock: {err}")

    @method()
    def SetGpuPowerProfile(self, value: "s"):
        profiles, _ = read_power_profiles()
        name = value.upper()
        if name not in GPU_POWER_PROFILES or name not in profiles:
            _fail(f"invalid GPU power profile {value}")
        _write(f"{_gpu_dev()}/pp_power_profile_mode", profiles[name])

    @method()
    def SetMaxChargeLevel(self, level: "i"):
        if level != -1 and not 1 <= level <= 100:
            _fail(f"invalid charge level {level}")
        d = _hwmon(attr="max_battery_charge_level")
        if not d:
            _fail("no max_battery_charge_level")
        _write(f"{d}/max_battery_charge_level", 0 if level == -1 else level)

    @method()
    def SetCpuScalingGovernor(self, governor: "s"):
        avail, _ = read_governors()
        if governor not in avail:
            _fail(f"invalid governor {governor}")
        for path in glob.glob("/sys/devices/system/cpu/cpufreq/policy*/scaling_governor"):
            _write(path, governor)

    @method()
    def SetCpuBoostState(self, state: "u"):
        _write("/sys/devices/system/cpu/cpufreq/boost", 1 if state else 0)

    @method()
    def SetLoginSession(self, which: "s", session: "s"):
        # which: "default" or "temp"; an empty session removes the file, so
        # SDDM falls back to the next one (temp -> default -> io-session's
        # game mode).
        path = {"default": SDDM_DEFAULT, "temp": SDDM_TEMP}.get(which)
        if path is None:
            _fail(f"unknown login file: {which}")
        if not session:
            try:
                os.remove(path)
            except FileNotFoundError:
                pass
            return
        if session not in (GAME_SESSION, DESKTOP_SESSION):
            _fail(f"unknown session: {session}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"[Autologin]\nSession={session}\n")

    @method()
    def SetCpuScheduler(self, scheduler: "s"):
        # As SteamOS enables and disables scx.service: the runit service is
        # linked while lavd is chosen, and removed for "none".
        if scheduler not in available_cpu_schedulers():
            _fail(f"unknown CPU scheduler: {scheduler}")
        if scheduler == "lavd":
            if not os.path.islink(SCX_SERVICE_LINK):
                os.symlink(SCX_SERVICE_DIR, SCX_SERVICE_LINK)
        else:
            if os.path.islink(SCX_SERVICE_LINK):
                subprocess.run(["sv", "-w", "5", "down", SCX_SERVICE_DIR], check=False)
                os.remove(SCX_SERVICE_LINK)

    @method()
    def SetWifiBackend(self, backend: "s"):
        # Valve's tool writes the override and restarts NetworkManager with
        # the new backend (Io's copy uses runit).
        if backend not in ("iwd", "wpa_supplicant"):
            _fail(f"unknown Wi-Fi backend: {backend}")
        result = subprocess.run(["/usr/bin/steamos-wifi-set-backend", backend],
                                capture_output=True, text=True, check=False)
        if result.returncode != 0:
            _fail(f"steamos-wifi-set-backend failed: {result.stderr.strip()}")

    @method()
    def SetWifiPowerManagementState(self, state: "u"):
        ifname = _wifi_iface()
        if not ifname:
            _fail("no wireless interface")
        mode = "on" if state else "off"
        # As on SteamOS, the setting goes into NetworkManager's configuration
        # (wifi.powersave: 3 on, 2 off), so it survives reconnects and backend
        # switches; iw applies it to the running connection right away.
        try:
            os.makedirs(os.path.dirname(WIFI_POWERSAVE_CONF), exist_ok=True)
            with open(WIFI_POWERSAVE_CONF, "w") as f:
                f.write(f"[connection]\nwifi.powersave={3 if state else 2}\n")
            subprocess.run(["nmcli", "general", "reload", "conf"], check=False)
        except OSError as err:
            log(f"could not write {WIFI_POWERSAVE_CONF}: {err}")
        # Also for iwd, whichever backend runs now: the setting is then
        # already in place after a switch. iwd reads it when it starts.
        try:
            _write_iwd_powersave(bool(state))
        except (OSError, ValueError) as err:
            log(f"could not write {IWD_MAIN_CONF}: {err}")
        try:
            subprocess.run(["iw", "dev", ifname, "set", "power_save", mode], check=False)
        except OSError as err:
            _fail(f"iw failed: {err}")

    @dbus_property()
    def FanControlState(self) -> "u":
        return read_fan_state()

    @FanControlState.setter
    def FanControlState(self, value: "u"):
        # runit's finish script returns the fan to the EC on 'down'
        try:
            subprocess.run(["sv", "up" if value else "down", "jupiter-fan-control"],
                           check=False, stdout=subprocess.DEVNULL)
        except OSError as err:
            _fail(f"sv failed: {err}")

    @dbus_property(access=PropertyAccess.READ)
    def AlsCalibrationGain(self) -> "ad":
        slots = {"Jupiter": ["2"], "Galileo": ["2", "4"]}.get(_board(), [])
        gains = []
        for slot in slots:
            out = subprocess.run(["dmidecode", "--oem-string", slot],
                                 capture_output=True, text=True, check=False)
            try:
                gains.append(float(out.stdout.strip()))
            except ValueError:
                gains.append(-1.0)
        return gains


async def run_root():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    bus.export(OBJPATH, RootManager(Jobs(bus, first=int(time.time()))))
    await bus.request_name(BUSNAME)
    log("root daemon ready")
    await bus.wait_for_disconnect()


# ================================================================== USER

class Root:
    """Client for the root daemon on the system bus. Setters on the session
    side are synchronous in dbus_fast, so each write is scheduled as a task;
    when it finishes, the interface re-reads sysfs and announces the value
    that is really in effect."""

    def __init__(self, bus):
        self.bus = bus
        self.tasks = set()

    async def _call(self, member, signature, body, iface=ROOT_IFACE):
        reply = await self.bus.call(Message(
            destination=BUSNAME, path=OBJPATH, interface=iface,
            member=member, signature=signature, body=body))
        if reply.message_type == MessageType.ERROR:
            log(f"{member} failed: {reply.error_name} {reply.body}")
            return None
        return reply.body

    async def call_raise(self, member, signature, body, path=OBJPATH, iface=ROOT_IFACE):
        """Like _call, but hands the root daemon's error on to the caller."""
        reply = await self.bus.call(Message(
            destination=BUSNAME, path=path, interface=iface,
            member=member, signature=signature, body=body))
        if reply.message_type == MessageType.ERROR:
            text = reply.body[0] if reply.body else reply.error_name
            raise DBusError(reply.error_name, text)
        return reply.body

    def write(self, member, signature, body, owner, props, iface=ROOT_IFACE):
        async def job():
            await self._call(member, signature, body, iface=iface)
            owner.emit_properties_changed({p: getattr(owner, p) for p in props})
        task = asyncio.ensure_future(job())
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    def set_prop(self, name, sig, value, owner, props):
        body = [ROOT_IFACE, name, Variant(sig, value)]
        self.write("Set", "ssv", body, owner, props,
                   iface="org.freedesktop.DBus.Properties")

    async def get_prop(self, name):
        body = await self._call("Get", "ss", [ROOT_IFACE, name],
                                iface="org.freedesktop.DBus.Properties")
        return body[0].value if body else None


class Manager2(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.Manager2")

    @method()
    def ReloadConfig(self):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def DeviceModel(self) -> "(ss)":
        board = _board()
        if board in ("Jupiter", "Galileo"):
            return ["steam_deck", board]
        return ["unknown", "unknown"]


# Screen reader, as steamos-manager (screenreader.rs): Orca speaks through
# speech-dispatcher; settings live in Orca's user-settings.conf and Orca
# reloads them on SIGUSR1; SIGUSR2 stops it talking; a virtual keyboard named
# "steamos-manager" presses Orca's shortcuts for modes and navigation.
# SteamOS runs Orca as a user service with gamescope's environment; here the
# user half starts it with the display settings of the running Steam.
ORCA_SETTINGS = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
                             "orca", "user-settings.conf")
A11Y_SCHEMA = "org.gnome.desktop.a11y.applications"
SR_LIMITS = {"average-pitch": (0.0, 10.0), "rate": (0.0, 100.0), "gain": (0.0, 10.0)}
SR_DEFAULTS = {"average-pitch": 5.0, "rate": 50.0, "gain": 10.0}
SR_ACTIONS = ["stop_talking", "read_next_word", "read_previous_word", "read_next_item",
              "read_previous_item", "move_to_next_landmark", "move_to_previous_landmark",
              "move_to_next_heading", "move_to_previous_heading", "toggle_mode"]
SR_MODES = ["browse", "focus"]


class OrcaManager:
    def __init__(self):
        self.mode = "browse"      # Valve: always browse at start, nothing stores it
        self.voice_locale = ""
        self.voices = {}          # name -> (language, variant)
        self.by_language = {}     # language -> [names]
        self.values = dict(SR_DEFAULTS)
        self.voice = ""
        self.enabled = self._gsettings_enabled()
        self._complete()
        self._load_values()
        self._load_voices()
        self.keyboard = None
        try:
            from evdev import UInput, ecodes as e
            self.e = e
            keys = [e.KEY_A, e.KEY_H, e.KEY_M, e.KEY_INSERT, e.KEY_LEFTCTRL, e.KEY_LEFTSHIFT,
                    e.KEY_DOWN, e.KEY_LEFT, e.KEY_RIGHT, e.KEY_UP]
            self.keyboard = UInput({e.EV_KEY: keys}, name="steamos-manager")
        except Exception as err:  # noqa: BLE001 - no keyboard, no shortcuts
            log(f"screen reader: no virtual keyboard: {err}")

    # --- settings file -------------------------------------------------
    def _read(self):
        try:
            with open(ORCA_SETTINGS, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return {}

    def _write(self, data):
        os.makedirs(os.path.dirname(ORCA_SETTINGS), exist_ok=True)
        with open(ORCA_SETTINGS, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    def _complete(self):
        # Orca reads general, pronunciations, keybindings and profiles and
        # fails on a missing one. It writes all of them itself when it creates
        # the file; when this manager wrote first (Steam setting a voice before
        # Orca ever ran), they are added here. Existing values stay.
        if not os.path.exists(ORCA_SETTINGS):
            return
        data = self._read()
        before = json.dumps(data, sort_keys=True)
        for key in ("general", "pronunciations", "keybindings", "profiles"):
            if not isinstance(data.get(key), dict):
                data[key] = {}
        default = data["profiles"].setdefault("default", {})
        default.setdefault("profile", ["Default", "default"])
        if json.dumps(data, sort_keys=True) != before:
            self._write(data)
            log("screen reader: completed Orca's user-settings.conf")

    def _default_voice(self, data):
        return (data.setdefault("profiles", {}).setdefault("default", {})
                .setdefault("voices", {}).setdefault("default", {}))

    def _load_values(self):
        voice = self._read().get("profiles", {}).get("default", {}).get("voices", {}).get("default", {})
        for key in SR_DEFAULTS:
            try:
                self.values[key] = float(voice.get(key, SR_DEFAULTS[key]))
            except (TypeError, ValueError):
                self.values[key] = SR_DEFAULTS[key]
        self.voice = str(voice.get("family", {}).get("name", "") or "")

    def _load_voices(self):
        voices = []
        try:
            import speechd
            client = speechd.SSIPClient("steamos-manager")
            voices = list(client.list_synthesis_voices())
            client.close()
        except Exception as err:  # noqa: BLE001
            log(f"screen reader: speechd module: {err}; asking spd-say")
            # spd-say -L: a header, then NAME LANGUAGE VARIANT in columns
            # separated by two or more spaces (names can contain single ones)
            out = subprocess.run(["spd-say", "-L"], capture_output=True, text=True,
                                 timeout=10, check=False).stdout
            for line in out.splitlines()[1:]:
                cols = [c for c in re.split(r"\s{2,}", line.strip()) if c]
                if len(cols) >= 2:
                    voices.append((cols[0], cols[1], cols[2] if len(cols) > 2 else "none"))
        for name, language, variant in voices:
            self.voices[name] = (language, variant)
            self.by_language.setdefault(language, []).append(name)

    # --- orca ------------------------------------------------------------
    @staticmethod
    def _gsettings_enabled():
        out = subprocess.run(["gsettings", "get", A11Y_SCHEMA, "screen-reader-enabled"],
                             capture_output=True, text=True, check=False).stdout.strip()
        return out == "true"

    @staticmethod
    def _orca_pid():
        out = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "orca"],
                             capture_output=True, text=True, check=False).stdout.split()
        return int(out[0]) if out else None

    @staticmethod
    def _display_env():
        env = dict(os.environ)
        steam = subprocess.run(["pgrep", "-o", "-u", str(os.getuid()), "-x", "steam"],
                               capture_output=True, text=True, check=False).stdout.split()
        if steam:
            try:
                with open(f"/proc/{steam[0]}/environ", "rb") as f:
                    for item in f.read().split(b"\0"):
                        key, _, value = item.decode(errors="replace").partition("=")
                        if key in ("DISPLAY", "WAYLAND_DISPLAY", "GAMESCOPE_WAYLAND_DISPLAY",
                                   "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE"):
                            env[key] = value
            except OSError:
                pass
        return env

    def _stop_orca(self):
        subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "orca"], check=False)

    def _restart_orca(self):
        self._stop_orca()
        self._complete()
        # setsid -f: Orca runs detached, so its end is reaped by the system
        # instead of lingering as a zombie of this process.
        subprocess.run(["setsid", "-f", "orca"], env=self._display_env(), check=False)

    def _signal_orca(self, sig):
        pid = self._orca_pid()
        if pid:
            os.kill(pid, sig)

    # --- operations --------------------------------------------------------
    def set_enabled(self, enable):
        if enable != self.enabled:
            subprocess.run(["gsettings", "set", A11Y_SCHEMA, "screen-reader-enabled",
                            "true" if enable else "false"], check=False)
            data = self._read()
            data.setdefault("general", {})["enableSpeech"] = bool(enable)
            self._write(data)
        if enable:
            self._restart_orca()
        else:
            self._stop_orca()
        self.enabled = enable
        # A (re)started Orca begins in browse mode.
        self.mode = "browse"

    def set_value(self, key, value):
        low, high = SR_LIMITS[key]
        if not low <= value <= high:
            raise DBusError(ERR, f"{key} {value} out of range {low}-{high}")
        data = self._read()
        self._default_voice(data)[key] = value
        self._write(data)
        self.values[key] = value
        self._signal_orca(signal.SIGUSR1)

    def set_voice(self, name):
        if name not in self.voices:
            raise DBusError(ERR, f"unknown voice: {name}")
        language, variant = self.voices[name]
        lang, _, dialect = language.partition("-")
        data = self._read()
        voice = self._default_voice(data)
        voice["family"] = dict(voice.get("family", {}), name=name, lang=lang,
                               variant=variant, dialect=dialect)
        voice["established"] = True
        self._write(data)
        self.voice = name
        self._signal_orca(signal.SIGUSR1)

    def _press(self, *keys):
        # keys: all but the last are held, the last is pressed (Orca shortcuts)
        if not self.keyboard:
            raise DBusError(ERR, "no virtual keyboard")
        ui, e = self.keyboard, self.e
        for k in keys[:-1]:
            ui.write(e.EV_KEY, k, 1)
        ui.write(e.EV_KEY, keys[-1], 1)
        ui.syn()
        ui.write(e.EV_KEY, keys[-1], 0)
        for k in reversed(keys[:-1]):
            ui.write(e.EV_KEY, k, 0)
        ui.syn()

    def _insert_a(self, count):
        if not self.keyboard:
            raise DBusError(ERR, "no virtual keyboard")
        ui, e = self.keyboard, self.e
        ui.write(e.EV_KEY, e.KEY_INSERT, 1)
        for _ in range(count):
            ui.write(e.EV_KEY, e.KEY_A, 1)
            ui.syn()
            ui.write(e.EV_KEY, e.KEY_A, 0)
            ui.syn()
        ui.write(e.EV_KEY, e.KEY_INSERT, 0)
        ui.syn()

    def set_mode(self, mode):
        # Orca's shortcuts are plain key presses on a virtual keyboard: with
        # no screen reader running they land in whatever has the focus (Steam
        # sets the mode at every start, which typed "aa" into Plasma's
        # search). Only a running Orca gets them.
        if not self.enabled:
            return
        if mode == self.mode:
            return
        # Insert+A twice: focus mode sticky; three times: browse mode sticky
        self._insert_a(2 if mode == "focus" else 3)
        self.mode = mode

    def trigger(self, action):
        e = self.keyboard and self.e
        if action == "stop_talking":
            self._signal_orca(signal.SIGUSR2)
        elif not self.enabled:
            return
        elif action == "toggle_mode":
            self._insert_a(1)
            self.mode = "focus" if self.mode == "browse" else "browse"
        elif not e:
            raise DBusError(ERR, "no virtual keyboard")
        else:
            keys = {
                "read_next_word": (e.KEY_LEFTCTRL, e.KEY_RIGHT),
                "read_previous_word": (e.KEY_LEFTCTRL, e.KEY_LEFT),
                "read_next_item": (e.KEY_DOWN,),
                "read_previous_item": (e.KEY_UP,),
                "move_to_next_landmark": (e.KEY_M,),
                "move_to_previous_landmark": (e.KEY_LEFTSHIFT, e.KEY_M),
                "move_to_next_heading": (e.KEY_H,),
                "move_to_previous_heading": (e.KEY_LEFTSHIFT, e.KEY_H),
            }
            self._press(*keys[action])


ORCA = None


def orca():
    global ORCA
    if ORCA is None:
        ORCA = OrcaManager()
    return ORCA


class ScreenReader0(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.ScreenReader0")
        self.o = orca()

    @dbus_property()
    def Enabled(self) -> "b":
        return self.o.enabled

    @Enabled.setter
    def Enabled(self, value: "b"):
        self.o.set_enabled(value)

    @dbus_property()
    def Rate(self) -> "d":
        return self.o.values["rate"]

    @Rate.setter
    def Rate(self, value: "d"):
        self.o.set_value("rate", value)

    @dbus_property()
    def Pitch(self) -> "d":
        return self.o.values["average-pitch"]

    @Pitch.setter
    def Pitch(self, value: "d"):
        self.o.set_value("average-pitch", value)

    @dbus_property()
    def Volume(self) -> "d":
        return self.o.values["gain"]

    @Volume.setter
    def Volume(self, value: "d"):
        self.o.set_value("gain", value)

    @dbus_property()
    def Mode(self) -> "u":
        return SR_MODES.index(self.o.mode)

    @Mode.setter
    def Mode(self, value: "u"):
        if value >= len(SR_MODES):
            raise DBusError(ERR, f"unknown mode: {value}")
        self.o.set_mode(SR_MODES[value])
        self.emit_properties_changed({"Mode": value})

    @dbus_property()
    def Voice(self) -> "s":
        return self.o.voice

    @Voice.setter
    def Voice(self, value: "s"):
        self.o.set_voice(value)
        self.emit_properties_changed({"Voice": value})

    @dbus_property(access=PropertyAccess.READ)
    def VoiceLocales(self) -> "as":
        return sorted(self.o.by_language)

    @dbus_property(access=PropertyAccess.READ)
    def VoicesForLocale(self) -> "a{sas}":
        return self.o.by_language

    @method()
    def TriggerAction(self, action: "u", timestamp: "t"):
        if action >= len(SR_ACTIONS):
            raise DBusError(ERR, f"unknown action: {action}")
        self.o.trigger(SR_ACTIONS[action])


class ScreenReader1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.ScreenReader1")
        self.o = orca()

    @dbus_property()
    def Enabled(self) -> "b":
        return self.o.enabled

    @Enabled.setter
    def Enabled(self, value: "b"):
        self.o.set_enabled(value)

    @dbus_property()
    def Rate(self) -> "d":
        return self.o.values["rate"]

    @Rate.setter
    def Rate(self, value: "d"):
        self.o.set_value("rate", value)

    @dbus_property()
    def Pitch(self) -> "d":
        return self.o.values["average-pitch"]

    @Pitch.setter
    def Pitch(self, value: "d"):
        self.o.set_value("average-pitch", value)

    @dbus_property()
    def Volume(self) -> "d":
        return self.o.values["gain"]

    @Volume.setter
    def Volume(self, value: "d"):
        self.o.set_value("gain", value)

    @dbus_property()
    def Mode(self) -> "s":
        return self.o.mode

    @Mode.setter
    def Mode(self, value: "s"):
        if value not in SR_MODES:
            raise DBusError(ERR, f"unknown mode: {value}")
        self.o.set_mode(value)
        self.emit_properties_changed({"Mode": value})

    @dbus_property(access=PropertyAccess.READ)
    def VoiceLocales(self) -> "as":
        return sorted(self.o.by_language)

    @dbus_property()
    def VoiceLocale(self) -> "s":
        return self.o.voice_locale

    @VoiceLocale.setter
    def VoiceLocale(self, value: "s"):
        if value and value not in self.o.by_language:
            raise DBusError(ERR, f"unknown voice locale: {value}")
        self.o.voice_locale = value

    @dbus_property()
    def Voice(self) -> "s":
        return self.o.voice

    @Voice.setter
    def Voice(self, value: "s"):
        self.o.set_voice(value)
        self.emit_properties_changed({"Voice": value})

    @method()
    def GetVoices(self) -> "as":
        return self.o.by_language.get(self.o.voice_locale, [])

    @method()
    def GetVoicesForLocale(self, locale: "s") -> "as":
        return self.o.by_language.get(locale, [])

    @method()
    def TriggerAction(self, action: "s", timestamp: "t"):
        if action not in SR_ACTIONS:
            raise DBusError(ERR, f"unknown action: {action}")
        self.o.trigger(action)


# HDMI-CEC, as steamos-manager (cec.rs, 26.4.1): two files in cecd's
# configuration, the same as on SteamOS (captured on 3.8.4 and 3.9.2): 00
# names the device, 99 holds Steam's switches. After a change cecd reloads
# its configuration through its own D-Bus API (Config1.Reload); MakeActive
# asks cecd to wake the TV and take the input (Daemon1.Wake).
# The four switches of 99-steamos-manager.toml, in Valve's order:
#   wake_tv        wake the TV when the Deck wakes
#   suspend_tv     put the TV into standby when the Deck sleeps
#   uinput         relay the TV remote to Steam ("enable control")
#   allow_standby  let the TV's standby suspend the Deck
# Valve rebuilds the file from the values cecd reports; Io keeps its own copy
# in the file and changes one switch at a time, so two quick changes cannot
# undo each other while cecd is still reloading.
# HdmiCecState (HdmiCec1) as Valve maps it: 3 ("extended") when suspend_tv or
# allow_standby is on, else 2 (control and wake), 1 (control only) or 0.
# Without the file Io starts as before in state 2 (control and wake).
CECD_CONF = os.path.expanduser("~/.config/cecd/config.d")
CECD_IDENTITY = 'osd_name = "Steam Deck"\nvendor_id = "e0-31-9e"\n'
CECD_RUNTIME = "99-steamos-manager.toml"
CECD_KEYS = ("wake_tv", "suspend_tv", "uinput", "allow_standby")
CECD_INITIAL = {"wake_tv": True, "suspend_tv": False, "uinput": True,
                "allow_standby": False}
# cecd's own defaults for a key the file does not set (its README)
CECD_DEFAULTS = {"wake_tv": False, "suspend_tv": False, "uinput": True,
                 "allow_standby": False}
CECD_BUSNAME = "com.steampowered.CecDaemon1"
CECD_PATH = "/com/steampowered/CecDaemon1/Daemon"
# The session bus, for calls to cecd (set by run_user).
SESSION_BUS = None


def _cecd_write(name, text):
    os.makedirs(CECD_CONF, exist_ok=True)
    path = os.path.join(CECD_CONF, name)
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def read_cec_config():
    try:
        with open(os.path.join(CECD_CONF, CECD_RUNTIME), encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return dict(CECD_INITIAL)
    config = dict(CECD_DEFAULTS)
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        key = key.strip()
        if sep and key in CECD_KEYS:
            config[key] = value.strip().lower() == "true"
    return config


async def _cecd_call(interface, member):
    """One call to cecd on the session bus (D-Bus activation starts it)."""
    if SESSION_BUS is None:
        raise DBusError(ERR, "no session bus")
    reply = await SESSION_BUS.call(Message(
        destination=CECD_BUSNAME, path=CECD_PATH,
        interface=f"{CECD_BUSNAME}.{interface}", member=member))
    if reply.message_type == MessageType.ERROR:
        text = reply.body[0] if reply.body else reply.error_name
        raise DBusError(reply.error_name, text)


async def _cecd_reload():
    try:
        await _cecd_call("Config1", "Reload")
    except DBusError as err:
        log(f"cecd reload failed: {err.text}")


def write_cec_config(config):
    """Write both files; ask cecd to reload when something changed."""
    text = "".join(f"{k} = {'true' if config[k] else 'false'}\n" for k in CECD_KEYS)
    changed = _cecd_write("00-steamos-manager.toml", CECD_IDENTITY)
    changed |= _cecd_write(CECD_RUNTIME, text)
    if changed and SESSION_BUS is not None:
        task = asyncio.ensure_future(_cecd_reload())
        _CEC_TASKS.add(task)
        task.add_done_callback(_CEC_TASKS.discard)


_CEC_TASKS = set()


def cec_state(config):
    if config["suspend_tv"] or config["allow_standby"]:
        return 3
    if config["uinput"]:
        return 2 if config["wake_tv"] else 1
    return 0


class HdmiCec1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.HdmiCec1")
        # Make sure cecd has both files, as steamos-manager does at session start.
        write_cec_config(read_cec_config())

    @dbus_property()
    def HdmiCecState(self) -> "u":
        return cec_state(read_cec_config())

    @HdmiCecState.setter
    def HdmiCecState(self, value: "u"):
        if value not in (0, 1, 2, 3):
            raise DBusError(ERR, f"unknown HDMI-CEC state: {value}")
        # As Valve's set_enabled_state: 3 turns control on and the rest off.
        write_cec_config({"wake_tv": value == 2, "uinput": value != 0,
                          "suspend_tv": False, "allow_standby": False})
        self.emit_properties_changed({"HdmiCecState": cec_state(read_cec_config())})


class HdmiCec2(ServiceInterface):
    """steamos-manager 26.4.1: Steam's CEC switches one by one (SteamOS 3.9.2's
    Steam beta sets them from the power menu) and MakeActive. Waking the Deck
    from the TV needs CEC wake hardware (a ChromeOS EC on Valve's newer
    devices); the Deck LCD has none, as WakeDeviceSupported says."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.HdmiCec2")

    def _set(self, key, value, prop):
        config = read_cec_config()
        config[key] = bool(value)
        write_cec_config(config)
        self.emit_properties_changed({prop: read_cec_config()[key]})

    @dbus_property()
    def EnableControl(self) -> "b":
        return read_cec_config()["uinput"]

    @EnableControl.setter
    def EnableControl(self, value: "b"):
        self._set("uinput", value, "EnableControl")

    @dbus_property()
    def SuspendTv(self) -> "b":
        return read_cec_config()["suspend_tv"]

    @SuspendTv.setter
    def SuspendTv(self, value: "b"):
        self._set("suspend_tv", value, "SuspendTv")

    @dbus_property()
    def SuspendDevice(self) -> "b":
        return read_cec_config()["allow_standby"]

    @SuspendDevice.setter
    def SuspendDevice(self, value: "b"):
        self._set("allow_standby", value, "SuspendDevice")

    @dbus_property()
    def WakeTv(self) -> "b":
        return read_cec_config()["wake_tv"]

    @WakeTv.setter
    def WakeTv(self, value: "b"):
        self._set("wake_tv", value, "WakeTv")

    @dbus_property()
    def WakeDevice(self) -> "b":
        return False

    @WakeDevice.setter
    def WakeDevice(self, value: "b"):
        raise DBusError(ERR, "HDMI CEC hardware not configured")

    @dbus_property(access=PropertyAccess.READ)
    def WakeDeviceSupported(self) -> "b":
        return False

    @method()
    async def MakeActive(self):
        await _cecd_call("Daemon1", "Wake")


# Download mode, as steamos-manager: while Steam holds at least one handle,
# the TDP limit is lowered to the Deck's download_mode_limit (Valve's
# data/devices/steam-deck.toml in steamos-manager 26.1.0: 6 W) and restored
# when the last handle is closed.
DOWNLOAD_MODE_TDP = 6


class LowPowerMode1(ServiceInterface):
    """EnterDownloadMode hands out the write end of a pipe; the mode lasts
    until every handed-out end is closed (or its holder exits)."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.LowPowerMode1")
        self.root = root
        self.handles = {}
        self.previous_tdp = None

    async def _update(self):
        if self.handles:
            if self.previous_tdp is None:
                self.previous_tdp = read_tdp()
                log(f"download mode: TDP {self.previous_tdp} -> {DOWNLOAD_MODE_TDP} W")
            if read_tdp() != DOWNLOAD_MODE_TDP:
                await self.root._call("SetTdpLimit", "u", [DOWNLOAD_MODE_TDP])
        elif self.previous_tdp is not None:
            log(f"download mode ends: TDP back to {self.previous_tdp} W")
            await self.root._call("SetTdpLimit", "u", [self.previous_tdp])
            self.previous_tdp = None

    def _closed(self, fd, identifier):
        loop = asyncio.get_running_loop()
        try:
            data = os.read(fd, 1024)
        except OSError:
            data = b""
        if data:
            return
        loop.remove_reader(fd)
        os.close(fd)
        count = self.handles.get(identifier, 0) - 1
        if count > 0:
            self.handles[identifier] = count
        else:
            self.handles.pop(identifier, None)
        loop.create_task(self._update())

    @method()
    async def EnterDownloadMode(self, identifier: "s") -> "h":
        read_end, write_end = os.pipe()
        loop = asyncio.get_running_loop()
        self.handles[identifier] = self.handles.get(identifier, 0) + 1
        loop.add_reader(read_end, self._closed, read_end, identifier)
        await self._update()
        # Our copy of the write end must go once the reply carries it, or the
        # pipe never reports the holder's close.
        loop.call_later(2, os.close, write_end)
        return write_end

    @method()
    def ListDownloadModeHandles(self) -> "a{su}":
        return dict(self.handles)


class TdpLimit1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.TdpLimit1")
        self.root = root

    @dbus_property()
    def TdpLimit(self) -> "u":
        return read_tdp()

    @TdpLimit.setter
    def TdpLimit(self, value: "u"):
        self.root.write("SetTdpLimit", "u", [value], self, ["TdpLimit"])

    @dbus_property(access=PropertyAccess.READ)
    def TdpLimitMin(self) -> "u":
        return TDP_MIN

    @dbus_property(access=PropertyAccess.READ)
    def TdpLimitMax(self) -> "u":
        return TDP_MAX


class BatteryChargeLimit1(ServiceInterface):
    """Kernel: 0 = no limit. D-Bus: -1 = no limit."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.BatteryChargeLimit1")
        self.root = root

    @dbus_property()
    def MaxChargeLevel(self) -> "i":
        return read_charge_level()

    @MaxChargeLevel.setter
    def MaxChargeLevel(self, value: "i"):
        self.root.write("SetMaxChargeLevel", "i", [value], self, ["MaxChargeLevel"])

    @dbus_property(access=PropertyAccess.READ)
    def SuggestedMinimumLimit(self) -> "i":
        return 10


class AmbientLightSensor1(ServiceInterface):
    """The gain comes from DMI OEM strings, which only root can read, so it
    is fetched once from the root daemon at startup and cached."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.AmbientLightSensor1")
        self.gain = []

    @dbus_property(access=PropertyAccess.READ)
    def AlsCalibrationGain(self) -> "ad":
        return self.gain


class SessionManagement1(ServiceInterface):
    """As steamos-manager: switching tells SDDM which session to log in next
    (through the root half, which writes /etc/sddm.conf.d) and ends the
    running one; SDDM logs deck in again (Relogin=true)."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.SessionManagement1")
        self.root = root

    def _default_mode(self):
        try:
            with open(SDDM_DEFAULT, encoding="utf-8") as f:
                return "desktop" if DESKTOP_SESSION in f.read() else "game"
        except OSError:
            return "game"

    @staticmethod
    def _end_session():
        # Detached and delayed, so the caller (Steam, the desktop shortcut)
        # gets its reply before its session goes.
        # Game mode ends with gamescope. Plasma is logged out through its own
        # session manager: ending kwin alone does not end it -
        # kwin_wayland_wrapper restarts kwin (without the shell), and the
        # session stays on a black screen. Only if Plasma does not answer,
        # the wrapper and kwin go directly. pkill -x matches the kernel's
        # process name, which is cut to 15 characters: the wrapper runs as
        # "kwin_wayland_wr".
        uid = os.getuid()
        if subprocess.run(["pgrep", "-u", str(uid), "-x", "gamescope-wl"],
                          stdout=subprocess.DEVNULL).returncode == 0:
            cmd = f"sleep 1; pkill -TERM -u {uid} -x gamescope-wl"
        else:
            cmd = ("sleep 1; busctl --user call org.kde.Shutdown /Shutdown "
                   "org.kde.Shutdown logout || "
                   f"pkill -TERM -u {uid} -x 'kwin_wayland_wr|kwin_wayland'")
        subprocess.Popen(["setsid", "sh", "-c", cmd], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    async def _switch(self, mode):
        if mode == "desktop":
            temp = DESKTOP_SESSION
        else:
            # Game mode is SDDM's own default; only a desktop default needs
            # a one-shot override.
            temp = GAME_SESSION if self._default_mode() == "desktop" else ""
        await self.root._call("SetLoginSession", "ss", ["temp", temp])
        self._end_session()

    @method()
    async def SwitchToDesktopMode(self):
        await self._switch("desktop")

    @method()
    async def SwitchToGameMode(self):
        await self._switch("game")

    @method()
    async def SwitchToLoginMode(self, login_mode: "s"):
        if login_mode not in ("game", "desktop"):
            raise DBusError(ERR, f"unknown login mode: {login_mode}")
        await self._switch(login_mode)

    # steamos-manager 26.4.1 (SteamOS 3.9.2): log out into a given desktop
    # session. Io has one desktop session; every plasma name Valve's
    # ValidDesktopSessions can list selects it, as DefaultDesktopSession does.
    @method()
    async def SwitchToDesktopSession(self, session: "s"):
        if session not in DESKTOP_ALIASES:
            raise DBusError(ERR, f"Invalid desktop session {session}")
        await self._switch("desktop")

    @method()
    def ValidDesktopSessions(self) -> "as":
        return [DESKTOP_SESSION]

    @method()
    async def CleanTemporarySessions(self):
        await self.root._call("SetLoginSession", "ss", ["temp", ""])

    @dbus_property()
    def DefaultDesktopSession(self) -> "s":
        return DESKTOP_SESSION

    @DefaultDesktopSession.setter
    def DefaultDesktopSession(self, value: "s"):
        if value not in DESKTOP_ALIASES:
            raise DBusError(ERR, f"unknown desktop session: {value}")

    @dbus_property()
    def DefaultLoginMode(self) -> "s":
        return self._default_mode()

    @DefaultLoginMode.setter
    def DefaultLoginMode(self, value: "s"):
        if value not in ("game", "desktop"):
            raise DBusError(ERR, f"unknown login mode: {value}")
        session = DESKTOP_SESSION if value == "desktop" else ""
        self.root.write("SetLoginSession", "ss", ["default", session], self, ["DefaultLoginMode"])


class GpuPerformanceLevel1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.GpuPerformanceLevel1")
        self.root = root

    @dbus_property(access=PropertyAccess.READ)
    def AvailableGpuPerformanceLevels(self) -> "as":
        return ["auto", "low", "high", "manual", "profile_peak"]

    @dbus_property()
    def GpuPerformanceLevel(self) -> "s":
        return read_gpu_level()

    @GpuPerformanceLevel.setter
    def GpuPerformanceLevel(self, value: "s"):
        self.root.write("SetGpuPerformanceLevel", "s", [value], self,
                        ["GpuPerformanceLevel"])

    @dbus_property()
    def ManualGpuClock(self) -> "u":
        return read_od()[0]

    @ManualGpuClock.setter
    def ManualGpuClock(self, value: "u"):
        self.root.write("SetManualGpuClock", "u", [value], self,
                        ["ManualGpuClock"])

    @dbus_property(access=PropertyAccess.READ)
    def ManualGpuClockMin(self) -> "u":
        return read_od()[1]

    @dbus_property(access=PropertyAccess.READ)
    def ManualGpuClockMax(self) -> "u":
        return read_od()[2]


class GpuPowerProfile1(ServiceInterface):
    """Only CAPPED/UNCAPPED, exactly as on SteamOS. When neither is active
    the original cannot report a current profile; Io returns an empty
    string instead of an error, because a failing getter breaks dbus_fast's
    GetManagedObjects reply as a whole."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.GpuPowerProfile1")
        self.root = root

    @dbus_property(access=PropertyAccess.READ)
    def AvailableGpuPowerProfiles(self) -> "as":
        profiles, _ = read_power_profiles()
        return [p for p in GPU_POWER_PROFILES if p in profiles]

    @dbus_property()
    def GpuPowerProfile(self) -> "s":
        _, active = read_power_profiles()
        return active if active in GPU_POWER_PROFILES else ""

    @GpuPowerProfile.setter
    def GpuPowerProfile(self, value: "s"):
        self.root.write("SetGpuPowerProfile", "s", [value], self, ["GpuPowerProfile"])


class CpuScaling1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.CpuScaling1")
        self.root = root

    @dbus_property(access=PropertyAccess.READ)
    def AvailableCpuScalingGovernors(self) -> "as":
        return read_governors()[0]

    @dbus_property()
    def CpuScalingGovernor(self) -> "s":
        return read_governors()[1]

    @CpuScalingGovernor.setter
    def CpuScalingGovernor(self, value: "s"):
        self.root.write("SetCpuScalingGovernor", "s", [value], self,
                        ["CpuScalingGovernor"])


class CpuBoost1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.CpuBoost1")
        self.root = root

    @dbus_property()
    def CpuBoostState(self) -> "u":
        return read_boost()

    @CpuBoostState.setter
    def CpuBoostState(self, value: "u"):
        self.root.write("SetCpuBoostState", "u", [value], self, ["CpuBoostState"])


class CpuScheduler1(ServiceInterface):
    """none or lavd, as on SteamOS; lavd runs Void's scx_lavd through the
    runit service scx, linked by the root half."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.CpuScheduler1")
        self.root = root

    @dbus_property(access=PropertyAccess.READ)
    def AvailableCpuSchedulers(self) -> "as":
        return available_cpu_schedulers()

    @dbus_property()
    def CpuScheduler(self) -> "s":
        return "lavd" if os.path.islink(SCX_SERVICE_LINK) else "none"

    @CpuScheduler.setter
    def CpuScheduler(self, value: "s"):
        self.root.write("SetCpuScheduler", "s", [value], self, ["CpuScheduler"])


class RemoteInterface1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.RemoteInterface1")

    @dbus_property(access=PropertyAccess.READ)
    def RemoteInterfaces(self) -> "as":
        return []


class FanControl1(ServiceInterface):
    """1 = OS (jupiter-fan-control running), 0 = firmware/EC."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.FanControl1")
        self.root = root

    @dbus_property()
    def FanControlState(self) -> "u":
        return read_fan_state()

    @FanControlState.setter
    def FanControlState(self, value: "u"):
        self.root.set_prop("FanControlState", "u", 1 if value else 0, self,
                           ["FanControlState"])


class WifiPowerManagement1(ServiceInterface):
    def __init__(self, root):
        super().__init__(f"{IFACE}.WifiPowerManagement1")
        self.root = root

    @dbus_property()
    def WifiPowerManagementState(self) -> "u":
        return read_wifi_powersave()

    @WifiPowerManagementState.setter
    def WifiPowerManagementState(self, value: "u"):
        self.root.write("SetWifiPowerManagementState", "u", [1 if value else 0],
                        self, ["WifiPowerManagementState"])


class WifiBackend1(ServiceInterface):
    """The backend NetworkManager is really configured for (iwd by default,
    as on SteamOS); setting it switches through steamos-wifi-set-backend."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.WifiBackend1")
        self.root = root

    @dbus_property()
    def WifiBackend(self) -> "s":
        return read_wifi_backend()

    @WifiBackend.setter
    def WifiBackend(self, value: "s"):
        self.root.write("SetWifiBackend", "s", [value], self, ["WifiBackend"])


class MirroredJob(ServiceInterface):
    """User side of a job: the session bus object Steam holds, forwarding
    every call to the root daemon's job (steamos-manager's MirroredJob)."""

    def __init__(self, root, path):
        super().__init__(JOB_IFACE)
        self.root = root
        self.path = path

    async def _fwd(self, member, signature="", body=None):
        return await self.root.call_raise(member, signature, body or [],
                                          path=self.path, iface=JOB_IFACE)

    @method()
    async def Pause(self):
        await self._fwd("Pause")

    @method()
    async def Resume(self):
        await self._fwd("Resume")

    @method()
    async def Cancel(self, force: "b"):
        await self._fwd("Cancel", "b", [force])

    @method()
    async def Wait(self) -> "i":
        return (await self._fwd("Wait"))[0]

    @method()
    async def ExitCode(self) -> "i":
        return (await self._fwd("ExitCode"))[0]


class Storage1(ServiceInterface):
    """Steam's storage actions, run by the root daemon as jobs."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.Storage1")
        self.root = root
        self.jobs = None  # set in run_user, once the session bus is there
        self.mirrors = {}  # root job path -> session job path

    async def _job(self, member, signature="", body=None):
        body = await self.root.call_raise(member, signature, body or [])
        root_path = body[0]
        if root_path not in self.mirrors:
            self.mirrors[root_path] = self.jobs.add(MirroredJob(self.root, root_path))
        return self.mirrors[root_path]

    @method()
    async def TrimDevices(self) -> "o":
        return await self._job("TrimDevices")

    @method()
    async def FormatDevice(self, device: "s", label: "s", validate: "b") -> "o":
        return await self._job("FormatDevice", "ssb", [device, label, validate])


class ObjectManager(ServiceInterface):
    """Steam calls GetManagedObjects at '/' first (seen in both captures)."""

    def __init__(self, instances):
        super().__init__("org.freedesktop.DBus.ObjectManager")
        self.instances = instances

    @method()
    def GetManagedObjects(self) -> "a{oa{sa{sv}}}":
        ifaces = {}
        for inst in self.instances:
            props = {}
            for p in inst.introspect().properties:
                if p.access.name == "WRITE":
                    continue
                try:
                    props[p.name] = Variant(p.signature, getattr(inst, p.name))
                except Exception:  # noqa: BLE001 - skip unreadable ones
                    continue
            ifaces[inst.name] = props
        return {OBJPATH: ifaces}


USER_INTERFACES = (
    Manager2,
    TdpLimit1,
    BatteryChargeLimit1,
    AmbientLightSensor1,
    SessionManagement1,
    GpuPerformanceLevel1,
    GpuPowerProfile1,
    CpuScaling1,
    CpuBoost1,
    CpuScheduler1,
    RemoteInterface1,
    FanControl1,
    WifiPowerManagement1,
    WifiBackend1,
    LowPowerMode1,
    HdmiCec1,
    HdmiCec2,
    ScreenReader0,
    ScreenReader1,
    Storage1,
)


async def run_user():
    system = await MessageBus(bus_type=BusType.SYSTEM).connect()
    # Unix fds: LowPowerMode1.EnterDownloadMode returns one.
    session = await MessageBus(bus_type=BusType.SESSION, negotiate_unix_fd=True).connect()
    root = Root(system)
    global SESSION_BUS
    SESSION_BUS = session

    instances = []
    for cls in USER_INTERFACES:
        try:
            inst = cls(root)
            session.export(OBJPATH, inst)
            instances.append(inst)
        except Exception as err:  # noqa: BLE001 - one bad interface must not
            log(f"{cls.__name__} failed: {err}")  # take the service down

    for inst in instances:
        if isinstance(inst, AmbientLightSensor1):
            gain = await root.get_prop("AlsCalibrationGain")
            inst.gain = list(gain) if gain else []

    jobs = Jobs(session)
    for inst in instances:
        if isinstance(inst, Storage1):
            inst.jobs = jobs

    session.export("/", ObjectManager(instances))
    await session.request_name(BUSNAME)
    # A new session has started: a one-shot login from a switch has done
    # its job (steamos-manager does the same at session start).
    await root._call("SetLoginSession", "ss", ["temp", ""])
    log("user daemon ready")
    await session.wait_for_disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(run_root() if "-r" in sys.argv[1:] else run_user())
    except KeyboardInterrupt:
        sys.exit(0)
