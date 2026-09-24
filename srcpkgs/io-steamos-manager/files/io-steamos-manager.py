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

Not implemented (Io lacks the backing pieces): Storage1, Jobs, UdevEvents1,
LowPowerMode1, HdmiCec1, Audio1, ScreenReader0/1, UpdateBios1, UpdateDock1,
FactoryReset1, WifiDebug1.
"""

import asyncio
import glob
import os
import subprocess
import sys

from dbus_fast import BusType, Message, MessageType, PropertyAccess, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.errors import DBusError
from dbus_fast.service import ServiceInterface, dbus_property, method

BUSNAME = "com.steampowered.SteamOSManager1"
OBJPATH = "/com/steampowered/SteamOSManager1"
IFACE = "com.steampowered.SteamOSManager1"
ROOT_IFACE = f"{IFACE}.RootManager"
ERR = f"{IFACE}.Error.Failed"

STATE_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SESSION_STATE = os.path.join(STATE_DIR, "io-session-next")

# From Valve's /usr/share/steamos-manager/devices/steam-deck.toml
TDP_MIN = 3
TDP_MAX = 15
GPU_POWER_PROFILES = ("CAPPED", "UNCAPPED")
DESKTOP_SESSION = "plasma.desktop"


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


def _fail(msg):
    log(msg)
    raise DBusError(ERR, msg)


class RootManager(ServiceInterface):
    """Privileged half. Every method validates its input against the
    hardware's own limits before touching sysfs."""

    def __init__(self):
        super().__init__(ROOT_IFACE)

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
        # sustained and fast PPT limit, as SteamOS keeps them identical
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
        d = _gpu_dev()
        level = f"{d}/power_dpm_force_performance_level"
        if _read_file(level) != "manual":
            _write(level, "manual")
        od = f"{d}/pp_od_clk_voltage"
        _write(od, f"s 0 {clocks}")
        _write(od, f"s 1 {clocks}")
        _write(od, "c")

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
    bus.export(OBJPATH, RootManager())
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
    """Io writes the next session into a state file that io-start reads,
    then ends the running compositor; runit respawns the login."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.SessionManagement1")

    def _switch(self, target):
        try:
            with open(SESSION_STATE, "w", encoding="utf-8") as f:
                f.write(target)
        except OSError as err:
            log(f"cannot write session state: {err}")
            return
        victim = "gamescope-wl" if target == "desktop" else "kwin_wayland"
        subprocess.Popen(["setsid", "sh", "-c", f"sleep 1; pkill -TERM {victim}"],
                         start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @method()
    def SwitchToDesktopMode(self):
        self._switch("desktop")

    @method()
    def SwitchToGameMode(self):
        self._switch("gamemode")

    @method()
    def SwitchToLoginMode(self, login_mode: "s"):
        self._switch("desktop" if login_mode == "desktop" else "gamemode")

    @method()
    def ValidDesktopSessions(self) -> "as":
        return [DESKTOP_SESSION]

    @method()
    def CleanTemporarySessions(self):
        pass

    @dbus_property()
    def DefaultDesktopSession(self) -> "s":
        return DESKTOP_SESSION

    @DefaultDesktopSession.setter
    def DefaultDesktopSession(self, value: "s"):
        pass

    @dbus_property()
    def DefaultLoginMode(self) -> "s":
        return "game"

    @DefaultLoginMode.setter
    def DefaultLoginMode(self, value: "s"):
        pass


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
                        ["ManualGpuClock", "GpuPerformanceLevel"])

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
    """SteamOS offers none/lavd; lavd needs scx_scheds, which Io lacks."""

    def __init__(self, root):
        super().__init__(f"{IFACE}.CpuScheduler1")

    @dbus_property(access=PropertyAccess.READ)
    def AvailableCpuSchedulers(self) -> "as":
        return ["none"]

    @dbus_property()
    def CpuScheduler(self) -> "s":
        return "none"

    @CpuScheduler.setter
    def CpuScheduler(self, value: "s"):
        pass


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
)


async def run_user():
    system = await MessageBus(bus_type=BusType.SYSTEM).connect()
    session = await MessageBus(bus_type=BusType.SESSION).connect()
    root = Root(system)

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

    session.export("/", ObjectManager(instances))
    await session.request_name(BUSNAME)
    log("user daemon ready")
    await session.wait_for_disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(run_root() if "-r" in sys.argv[1:] else run_user())
    except KeyboardInterrupt:
        sys.exit(0)
