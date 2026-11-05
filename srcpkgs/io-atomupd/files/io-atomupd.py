#!/usr/bin/python3
"""io-atomupd: com.steampowered.Atomupd1 on the system bus, for Io.

On SteamOS atomupd-daemon serves Atomupd1 and installs system images. Io
updates with xbps, so it keeps its own service for that API; everything
else Steam needs comes from Valve's steamos-manager. Until Io moved to
Valve's daemon, io-steamos-manager's root half served it (same code).

Runs as root, as a runit service (io-atomupd). Callers are limited to root
and wheel by its D-Bus policy.
"""

import asyncio
import os
import subprocess
import sys
import time

from dbus_fast import BusType, PropertyAccess, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.errors import DBusError
from dbus_fast.service import ServiceInterface, dbus_property, method

ERR = "com.steampowered.Atomupd1.Error.Failed"
NOT_SUPPORTED = "org.freedesktop.DBus.Error.NotSupported"


def log(msg):
    print(f"io-atomupd: {msg}", file=sys.stderr, flush=True)


def _fail(msg):
    log(msg)
    raise DBusError(ERR, msg)


# com.steampowered.Atomupd1, as atomupd-daemon serves it on SteamOS
# (interface version 8, atomupd-daemon 0.20260821.0), with xbps behind it:
# /usr/libexec/io/io-update does the work, the same helper that
# /usr/bin/steamos-update (the script interface Steam uses for checks and
# updates) runs. Steam itself only calls DisableHttpProxy/EnableHttpProxy
# here, at every start; the rest is for other clients.
# One variant (steamdeck) and one branch (stable). Pause, resume and cancel
# are refused: xbps cannot be stopped safely in the middle of a transaction.

ATOMUPD_BUSNAME = "com.steampowered.Atomupd1"
ATOMUPD_PATH = "/com/steampowered/Atomupd1"
ATOMUPD_IFACE = "com.steampowered.Atomupd1"
ATOMUPD_VERSION = 8
IO_UPDATE = "/usr/libexec/io/io-update"
IO_UPDATE_STATE = "/run/io-update"
UPDATE_IDLE, UPDATE_IN_PROGRESS, UPDATE_PAUSED = 0, 1, 2
UPDATE_SUCCESSFUL, UPDATE_FAILED, UPDATE_CANCELLED = 3, 4, 5
BRANCH = "stable"
VARIANT = "steamdeck"


def _os_release():
    rel = {}
    try:
        with open("/etc/os-release") as f:
            for line in f:
                key, sep, value = line.strip().partition("=")
                if sep:
                    rel[key] = value.strip('"')
    except OSError:
        pass
    return rel


class Atomupd1(ServiceInterface):

    def __init__(self):
        super().__init__(ATOMUPD_IFACE)
        rel = _os_release()
        self.current_version = rel.get("VERSION_ID", "")
        self.current_build_id = rel.get("BUILD_ID", "")
        self.status = UPDATE_IDLE
        self.progress = 0.0
        self.eta = 0
        self.update_build_id = ""
        self.update_version = ""
        self.failure_code = ""
        self.failure_message = ""
        self.available = {}
        self.proxy = ("", 0)
        self.task = None
        # An update applied before a restart of this daemon still needs the
        # reboot, as atomupd-daemon reports it after its own restart.
        try:
            with open(f"{IO_UPDATE_STATE}/applied") as f:
                self.update_build_id = f.read().strip()
            self.status = UPDATE_SUCCESSFUL
            self.progress = 100.0
        except OSError:
            pass
        try:
            with open(f"{IO_UPDATE_STATE}/proxy") as f:
                addr, port = f.read().split()
                self.proxy = (addr, int(port))
        except (OSError, ValueError):
            pass

    def _changed(self, *names):
        self.emit_properties_changed({n: getattr(self, n) for n in names})

    # -------------------------------------------------------- properties
    @dbus_property(access=PropertyAccess.READ)
    def Version(self) -> "u":
        return ATOMUPD_VERSION

    @dbus_property(access=PropertyAccess.READ)
    def ProgressPercentage(self) -> "d":
        return self.progress

    @dbus_property(access=PropertyAccess.READ)
    def EstimatedCompletionTime(self) -> "t":
        return self.eta

    @dbus_property(access=PropertyAccess.READ)
    def UpdateStatus(self) -> "u":
        return self.status

    @dbus_property(access=PropertyAccess.READ)
    def UpdateBuildID(self) -> "s":
        return self.update_build_id

    @dbus_property(access=PropertyAccess.READ)
    def UpdateVersion(self) -> "s":
        return self.update_version

    @dbus_property(access=PropertyAccess.READ)
    def Variant(self) -> "s":
        return VARIANT

    @dbus_property(access=PropertyAccess.READ)
    def Branch(self) -> "s":
        return BRANCH

    @dbus_property(access=PropertyAccess.READ)
    def HttpProxy(self) -> "(si)":
        return list(self.proxy)

    @dbus_property(access=PropertyAccess.READ)
    def FailureCode(self) -> "s":
        return self.failure_code

    @dbus_property(access=PropertyAccess.READ)
    def FailureMessage(self) -> "s":
        return self.failure_message

    @dbus_property(access=PropertyAccess.READ)
    def UpdatesAvailable(self) -> "a{sa{sv}}":
        return self.available

    @dbus_property(access=PropertyAccess.READ)
    def UpdatesAvailableLater(self) -> "a{sa{sv}}":
        return {}

    @dbus_property(access=PropertyAccess.READ)
    def CurrentVersion(self) -> "s":
        return self.current_version

    @dbus_property(access=PropertyAccess.READ)
    def CurrentBuildID(self) -> "s":
        return self.current_build_id

    @dbus_property(access=PropertyAccess.READ)
    def KnownVariants(self) -> "as":
        return [VARIANT]

    @dbus_property(access=PropertyAccess.READ)
    def KnownBranches(self) -> "as":
        return [BRANCH]

    @dbus_property(access=PropertyAccess.READ)
    def KnownDevBranches(self) -> "as":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def SimulateUpdateResult(self) -> "a{sv}":
        return {}

    @dbus_property(access=PropertyAccess.READ)
    def SimulateUpdateStatus(self) -> "u":
        return UPDATE_IDLE

    @dbus_property(access=PropertyAccess.READ)
    def SimulateFailureMessage(self) -> "s":
        return ""

    # ----------------------------------------------------------- methods
    @method()
    def ReloadConfiguration(self, options: "a{sv}"):
        pass

    @method()
    def SwitchToVariant(self, variant: "s"):
        if variant != VARIANT:
            _fail(f"Io has no variant '{variant}'")

    @method()
    def SwitchToBranch(self, branch: "s"):
        if branch not in (BRANCH, "rel"):
            _fail(f"Io has no branch '{branch}'; it stays on {BRANCH}")

    @method()
    async def CheckForUpdates(self, options: "a{sv}") -> "a{sa{sv}}a{sa{sv}}":
        if self.status in (UPDATE_IN_PROGRESS, UPDATE_PAUSED):
            _fail("An update is already in progress")
        proc = await asyncio.create_subprocess_exec(
            IO_UPDATE, "check", stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = await proc.communicate()
        if proc.returncode == 7:
            self.available = {}
        elif proc.returncode == 0:
            build_id, _, size = out.decode().split()[:3]
            self.available = {build_id: {
                "version": Variant("s", self.current_version),
                "variant": Variant("s", VARIANT),
                "branch": Variant("s", BRANCH),
                "estimated_size": Variant("t", int(size)),
            }}
        else:
            _fail(f"Failed to check for updates: {err.decode().strip()}")
        self._changed("UpdatesAvailable")
        return [self.available, {}]

    @method()
    def StartUpdate(self, id: "s"):
        if self.status in (UPDATE_IN_PROGRESS, UPDATE_PAUSED):
            _fail("An update is already in progress")
        if id not in self.available:
            _fail(f"Update '{id}' is not available; call CheckForUpdates first")
        self.status = UPDATE_IN_PROGRESS
        self.progress = 0.0
        self.eta = 0
        self.update_build_id = id
        self.update_version = self.current_version
        self.failure_code = self.failure_message = ""
        self._changed("UpdateStatus", "ProgressPercentage", "EstimatedCompletionTime",
                      "UpdateBuildID", "UpdateVersion", "FailureCode", "FailureMessage")
        self.task = asyncio.ensure_future(self._apply())

    async def _apply(self):
        log("system update: starting io-update apply")
        try:
            proc = await asyncio.create_subprocess_exec(
                IO_UPDATE, "apply", stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            async for line in proc.stdout:
                parts = line.decode().split()
                if len(parts) == 3 and parts[0] == "progress":
                    self.progress = float(parts[1])
                    left = int(parts[2])
                    self.eta = int(time.time()) + left if left > 0 else 0
                    self._changed("ProgressPercentage", "EstimatedCompletionTime")
            err = (await proc.stderr.read()).decode().strip()
            rc = await proc.wait()
        except OSError as e:
            rc, err = 1, str(e)
        if rc in (0, 7):
            self.status = UPDATE_SUCCESSFUL
            self.progress = 100.0
            self.eta = 0
            self.available = {}
            log("system update: applied, reboot pending")
        else:
            self.status = UPDATE_FAILED
            self.failure_code = "org.freedesktop.DBus.Error.Failed"
            self.failure_message = err.splitlines()[-1] if err else f"io-update exited with {rc}"
            log(f"system update failed: {self.failure_message}")
        self._changed("UpdateStatus", "ProgressPercentage", "EstimatedCompletionTime",
                      "UpdatesAvailable", "FailureCode", "FailureMessage")

    @method()
    def StartCustomUpdate(self, options: "a{sv}"):
        raise DBusError(NOT_SUPPORTED, "Custom updates are not supported on Io")

    @method()
    def PauseUpdate(self):
        raise DBusError(NOT_SUPPORTED, "xbps updates cannot be paused")

    @method()
    def ResumeUpdate(self):
        raise DBusError(NOT_SUPPORTED, "xbps updates cannot be paused")

    @method()
    def CancelUpdate(self):
        raise DBusError(NOT_SUPPORTED, "xbps updates cannot be cancelled safely")

    @method()
    def EnableHttpProxy(self, address: "s", port: "i", options: "a{sv}"):
        if not address or not 0 < port < 65536 or any(c.isspace() for c in address):
            _fail("Invalid proxy address or port")
        os.makedirs(IO_UPDATE_STATE, exist_ok=True)
        with open(f"{IO_UPDATE_STATE}/proxy", "w") as f:
            f.write(f"{address} {port}\n")
        self.proxy = (address, port)
        self._changed("HttpProxy")

    @method()
    def DisableHttpProxy(self):
        try:
            os.unlink(f"{IO_UPDATE_STATE}/proxy")
        except FileNotFoundError:
            pass
        if self.proxy != ("", 0):
            self.proxy = ("", 0)
            self._changed("HttpProxy")

    @method()
    def EnableDevKeys(self, options: "a{sv}"):
        raise DBusError(NOT_SUPPORTED, "Io has no developer keys")

    @method()
    def DisableDevKeys(self, options: "a{sv}"):
        raise DBusError(NOT_SUPPORTED, "Io has no developer keys")

    @method()
    def GetBuilds(self, options: "a{sv}") -> "s":
        raise DBusError(NOT_SUPPORTED, "Io has no list of builds")

    @method()
    def SimulateUpdate(self, options: "a{sv}"):
        raise DBusError(NOT_SUPPORTED, "Simulated updates are not supported on Io")


async def main():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    bus.export(ATOMUPD_PATH, Atomupd1())
    await bus.request_name(ATOMUPD_BUSNAME)
    log("ready")
    await bus.wait_for_disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
