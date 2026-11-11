#!/usr/bin/env python3
"""upstream-check.py - what upstream has that Io has not taken yet.

Checks, each finding with a stable key so it is reported once:
  valve      Valve's package listings (pkgcheck.sh) against docs/*-latest.txt;
             a new SteamOS release branch on Valve's mirror
  overlay    each overlay's Void package: new version (patches to check) or
             new revision / io_revision not published in io-repo's current
  watch      Void packages Io waits for (ci/void-watch.txt)
  kernel     Io's kernel against Valve's (linux-neptune on the mirror), Void's
             (linux and linuxX.Y) and kernel.org's; a newer stable of Io's
             series, a new Valve kernel, a newer series, end of life; the
             three are listed in a table every run
  manager    Valve's steamos-manager main against srcpkgs/steamos-manager's
             _commit (Io's runit support is the template's patches)

Usage:
  ci/upstream-check.py               print the report
  ci/upstream-check.py --issue       also sync the GitHub issue (Actions:
                                     GITHUB_TOKEN, GITHUB_REPOSITORY)
"""
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
import plistlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALVE_SOURCES = "https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/"
VOID_RAW = "https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/{}/template"
IO_REPODATA = "https://github.com/Lolzen/io-repo/releases/download/current/x86_64-repodata"
KERNEL_DIR = "https://cdn.kernel.org/pub/linux/kernel/v{}.x/"
VALVE_MANAGER = "https://gitlab.steamos.cloud/holo/steamos-manager.git"
LABEL = "upstream-check"

findings = []   # (key, section, text)


def add(key, section, text):
    findings.append((key, section, text))


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": "io-upstream-check"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if binary else data.decode("utf-8", "replace")


def read(path):
    with open(os.path.join(ROOT, path)) as f:
        return f.read()


def vkey(v):
    return [(1, int(x), "") if x.isdigit() else (0, 0, x) for x in re.split(r"[._-]", v)]


def template_vars(text):
    out = {}
    for name in ("version", "revision", "_commit"):
        m = re.search(r"^%s=\"?([^\"\s]+)\"?" % name, text, re.M)
        if m:
            out[name] = m.group(1)
    return out


def conf_lines(path):
    lines = []
    for line in read(path).splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            lines.append(line)
    return lines


# --- Valve's packages -------------------------------------------------------

def check_valve():
    releases = pkg_releases()
    ignore = set(conf_lines("ci/valve-ignore.txt"))
    tmp = tempfile.mkdtemp()
    try:
        for f in os.listdir(os.path.join(ROOT, "docs")):
            if f.endswith("-latest.txt"):
                shutil.copy(os.path.join(ROOT, "docs", f), tmp)
        r = subprocess.run(["sh", os.path.join(ROOT, "pkgcheck.sh")], env=dict(os.environ, DOCS=tmp),
                           capture_output=True, text=True)
        for line in r.stderr.splitlines():
            if "unreachable" in line:
                add("error:" + line, "Errors", line)
        for branch in ["jupiter-main", "holo-main"] + [p + r for r in releases for p in ("jupiter-", "holo-")]:
            new_path = os.path.join(tmp, branch + "-latest.txt")
            old_path = os.path.join(ROOT, "docs", branch + "-latest.txt")
            if not os.path.exists(new_path):
                continue
            if not os.path.exists(old_path):
                add("valve-first:" + branch, "Valve's packages",
                    "`%s`: no list in `docs/` yet (run `./pkgcheck.sh` and commit `docs/`)" % branch)
                continue
            old = set(open(old_path).read().split())
            new = set(open(new_path).read().split())
            oldby = {pkgname(p): p for p in old}
            for p in sorted(new - old):
                name = pkgname(p)
                if name in ignore:
                    continue
                was = oldby.get(name, "new package")
                add("valve:%s:%s" % (branch, p), "Valve's packages",
                    "`%s`: %s → **%s**" % (branch, was, p))
            newnames = {pkgname(p) for p in new}
            for p in sorted(old - new):
                name = pkgname(p)
                if name not in newnames and name not in ignore:
                    add("valve:%s:gone:%s" % (branch, name), "Valve's packages",
                        "`%s`: %s removed" % (branch, p))
    finally:
        shutil.rmtree(tmp)

    index = fetch(VALVE_SOURCES)
    branches = set(re.findall(r'href="((?:jupiter|holo)-(\d+(?:\.\d+)*))/"', index))
    for name, ver in sorted(branches):
        if vkey(ver) > max(vkey(r) for r in releases):
            add("valve-branch:" + name, "Valve's packages",
                "new release branch `%s` on Valve's mirror (pkgcheck.sh has RELEASES=%s)" % (name, " ".join(releases)))


def pkg_releases():
    """The SteamOS releases pkgcheck.sh watches (its RELEASES default)."""
    return re.search(r'RELEASES=\$\{RELEASES:-"([0-9. ]+)"\}', read("pkgcheck.sh")).group(1).split()


def pkgname(p):
    return "-".join(p.split("-")[:-2])


# --- Void -------------------------------------------------------------------

def published():
    raw = fetch(IO_REPODATA, binary=True)
    try:
        import zstandard
        raw = zstandard.ZstdDecompressor().stream_reader(io.BytesIO(raw)).read()
    except ImportError:
        raw = subprocess.run(["zstd", "-dc"], input=raw, capture_output=True, check=True).stdout
    tf = tarfile.open(fileobj=io.BytesIO(raw))
    index = plistlib.loads(tf.extractfile("index.plist").read())
    return {k: v["pkgver"] for k, v in index.items()}


def check_overlays():
    pub = published()
    base = os.path.join(ROOT, "overlay")
    for name in sorted(os.listdir(base)):
        conf = os.path.join(base, name, "overlay.conf")
        if not os.path.isfile(conf):
            continue
        c = dict(l.split("=", 1) for l in conf_lines(os.path.join("overlay", name, "overlay.conf")))
        void = template_vars(fetch(VOID_RAW.format(name)))
        if void["version"] != c["base_version"]:
            add("overlay:%s:%s" % (name, void["version"]), "Overlays (Void)",
                "`%s`: Void has **%s**, the patches are for %s (check them, raise base_version)"
                % (name, void["version"], c["base_version"]))
            continue
        want = "%s-holo-%s_%d" % (name, void["version"], int(void["revision"]) * 100 + int(c["io_revision"]))
        have = pub.get(name + "-holo", "nothing")
        if have != want:
            add("overlay-build:" + want, "Overlays (Void)",
                "`%s-holo`: current has %s, Void revision %s gives **%s** (build and publish)"
                % (name, have, void["revision"], want))


def check_watch():
    for line in conf_lines("ci/void-watch.txt"):
        pkg, ver, why = line.split(None, 2)
        void = template_vars(fetch(VOID_RAW.format(pkg)))
        have = "%s_%s" % (void["version"], void["revision"]) if "_" in ver else void["version"]
        if have != ver:
            add("watch:%s:%s" % (pkg, have), "Waiting for Void",
                "`%s`: Void has **%s** (was %s): %s" % (pkg, have, ver, why))


KERNEL_RELEASES = "https://www.kernel.org/releases.json"
VALVE_KERNEL_RE = re.compile(r"linux-neptune-(\d+)((?:-[a-z][a-z-]*?)?)-(\d+\.\d+[0-9a-z.]*?)-(\d+(?:\.\d+)?)\.src\.tar\.gz")
kernel_overview = []  # lines for the kernel table, shown whether or not there is a finding


def series_of(v):
    return ".".join(v.split(".")[:2])


def check_kernel():
    """Io's kernel against Valve's, Void's and kernel.org's; lists all three."""
    # the kernel package of the newest series (linux-neptune-73, not its
    # -headers/-dbg links or the linux-neptune metapackage)
    pkgs = [d for d in os.listdir(os.path.join(ROOT, "srcpkgs")) if re.fullmatch(r"linux-neptune-\d+", d)]
    pkg = max(pkgs, key=lambda d: int(d.rsplit("-", 1)[1]))
    text = read(os.path.join("srcpkgs", pkg, "template"))
    io_ver = template_vars(text)["version"]
    io_series = series_of(io_ver)
    # Valve's base: a tag ("Valve's 7.2.7-valve2") or, before Valve's first
    # tag of a series, its integration branch ("Valve's 7.3/integration (<commit>")
    m = re.search(r"Valve's ([0-9.]+)-(valve\d+)", text)
    m2 = re.search(r"Valve's (\d+\.\d+)/integration \(([0-9a-f]+)", text)
    if m:
        io_valve = "%s.%s" % (m.group(1), m.group(2))
    elif m2:
        io_valve = "%s/integration %s" % (m2.group(1), m2.group(2)[:12])
    else:
        io_valve = "?"
    kernel_overview.append("| Io | `%s` %s (Valve's %s on stable %s) |" % (pkg, io_ver, io_valve, io_ver))

    # kernel.org: every maintained release, and the newest point release of Io's series
    rel = json.loads(fetch(KERNEL_RELEASES))["releases"]
    org = {r["moniker"] + " " + r["version"]: r for r in rel if r["moniker"] in ("mainline", "stable", "longterm")}
    stable = sorted((r["version"] for r in rel if r["moniker"] in ("stable", "longterm")), key=vkey)
    listing = fetch(KERNEL_DIR.format(io_ver.split(".")[0]))
    # the directory listing can lag behind releases.json (a cached copy), so both count
    found = set(re.findall(r"patch-(%s\.\d+)\.xz" % re.escape(io_series), listing))
    found |= {r["version"] for r in rel if series_of(r["version"]) == io_series and r["version"].count(".") == 2}
    found = sorted(found, key=vkey)
    org_series = found[-1] if found else io_ver
    eol = [r for r in rel if series_of(r["version"]) == io_series and r["iseol"]]
    listed = any(series_of(r["version"]) == io_series for r in rel if r["moniker"] in ("stable", "longterm"))
    kernel_overview.append("| kernel.org | %s; Io's series %s: %s%s |" % (
        ", ".join("%s %s" % (r["moniker"], r["version"]) for r in rel if r["moniker"] in ("mainline", "stable")),
        io_series, org_series, " (end of life)" if eol or not listed else ""))
    if vkey(org_series) > vkey(io_ver):
        add("kernel:" + org_series, "Kernel",
            "stable **%s** is out, `%s` is on %s (see the wiki's Kernel page)" % (org_series, pkg, io_ver))
    if eol or not listed:
        add("kernel-eol:" + io_series, "Kernel", "kernel.org no longer maintains **%s** (end of life)" % io_series)

    # Void: the default kernel (the linux metapackage) and every linuxX.Y from Io's series on
    void_default = template_vars(fetch(VOID_RAW.format("linux")))["version"]
    void = {}
    major, minor = (int(x) for x in io_series.split("."))
    for ma, mi in [(major, minor + i) for i in range(7)] + [(major + 1, i) for i in range(4)]:
        try:
            void["%d.%d" % (ma, mi)] = template_vars(fetch(VOID_RAW.format("linux%d.%d" % (ma, mi))))["version"]
        except urllib.error.HTTPError:
            pass
    kernel_overview.append("| Void | default `linux` %s; %s |" % (
        void_default, ", ".join("`linux%s` %s" % (k, v) for k, v in sorted(void.items(), key=lambda x: vkey(x[0])))
        or "no linux%s" % io_series))

    # Valve: linux-neptune packages on the mirror (main and the release branches)
    releases = pkg_releases()
    valve = {}
    for branch in ["jupiter-main"] + ["jupiter-" + r for r in releases]:
        for flavour_series, flavour, ver, prel in VALVE_KERNEL_RE.findall(fetch(VALVE_SOURCES + branch + "/")):
            name = "linux-neptune-" + flavour_series + flavour
            if name not in valve or vkey(ver + "-" + prel) > vkey(valve[name]):
                valve[name] = ver + "-" + prel
    regular = {n: v for n, v in valve.items() if re.fullmatch(r"linux-neptune-\d+", n)}
    newest_name = max(regular, key=lambda n: vkey(regular[n]))
    valve_ver = regular[newest_name].rsplit("-", 1)[0]
    newest_any = max(valve, key=lambda n: vkey(valve[n]))
    kernel_overview.append("| Valve | `%s` %s%s |" % (newest_name, regular[newest_name],
                                                      "; newest of all: `%s` %s" % (newest_any, valve[newest_any])
                                                      if newest_any != newest_name else ""))
    # a Valve kernel of Io's own series that Io does not carry yet
    same = {n: v for n, v in regular.items() if series_of(v) == io_series}
    if same:
        name = max(same, key=lambda n: vkey(same[n]))
        ver = same[name].rsplit("-", 1)[0]
        if ver != io_valve:
            add("valve-kernel:" + ver, "Kernel",
                "Valve's kernel is **%s** (`%s`), Io carries %s" % (ver, name, io_valve))

    # a newer series: one finding per series, its text follows the versions
    newer = set()
    for r in rel:
        if r["moniker"] in ("stable", "longterm") and vkey(series_of(r["version"])) > vkey(io_series):
            newer.add(series_of(r["version"]))
    newer |= {k for k in void if vkey(k) > vkey(io_series)}
    for n, v in valve.items():
        if vkey(series_of(v)) > vkey(io_series):
            newer.add(series_of(v))
    for s in sorted(newer, key=vkey):
        o = [r["version"] for r in rel if r["moniker"] in ("stable", "longterm") and series_of(r["version"]) == s]
        vv = ["`%s` %s" % (n, v) for n, v in sorted(valve.items()) if series_of(v) == s]
        add("kernel-series:" + s, "Kernel",
            "**%s** is available: kernel.org %s, Void %s, Valve %s" % (
                s, o[0] if o else "not stable yet", "`linux%s` %s" % (s, void[s]) if s in void else "not yet",
                ", ".join(vv) if vv else "not yet"))


# --- SteamOS Manager ---------------------------------------------------------

def git(*args, cwd=None):
    return subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True, text=True)


def check_manager():
    commit = template_vars(read("srcpkgs/steamos-manager/template"))["_commit"]
    r = git("ls-remote", VALVE_MANAGER, "refs/heads/main")
    if r.returncode or not r.stdout.strip():
        add("error:valve-gitlab", "Errors", "Valve's GitLab not reachable: " + r.stderr.strip()[:200])
        return
    valve = r.stdout.split()[0]
    if valve != commit:
        add("manager-valve:" + valve, "SteamOS Manager",
            "Valve's `main` is at **%s**, `srcpkgs/steamos-manager` builds %s (rebase the patches, raise the template)"
            % (valve[:9], commit[:9]))


# --- report and issue ---------------------------------------------------------

SECTIONS = ["SteamOS Manager", "Kernel", "Overlays (Void)", "Waiting for Void", "Valve's packages", "Errors"]

HOWTO = """
<details><summary>How a finding goes away</summary>

- **Valve's packages:** evaluate, then run `./pkgcheck.sh` and commit `docs/` (unimportant packages: `ci/valve-ignore.txt`)
- **New release branch:** add it to `RELEASES` in `pkgcheck.sh`, run `./pkgcheck.sh`, commit `docs/` (drop the old release once SteamOS has moved on)
- **Overlays:** raise `base_version` after checking the patches; build and publish to current
- **Waiting for Void:** take the change, then update or remove the line in `ci/void-watch.txt`
- **Kernel:** update the kernel package (a new stable or Valve version); a newer series stays listed until Io moves to it
- **SteamOS Manager:** `git am` the template's patches onto Valve's main, `format-patch` them back; raise `_commit`, version and checksum
</details>
"""


def report():
    out = []
    for s in SECTIONS:
        items = [t for k, sec, t in findings if sec == s]
        if items:
            out.append("### " + s)
            out += ["- [ ] " + t for t in items]
            out.append("")
    if kernel_overview:
        out += ["### Kernel versions", "", "| | |", "|---|---|"] + kernel_overview + [""]
    return "\n".join(out)


def api(method, path, body=None):
    req = urllib.request.Request("https://api.github.com/repos/%s%s" % (os.environ["GITHUB_REPOSITORY"], path),
                                 method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
                                          "Accept": "application/vnd.github+json",
                                          "User-Agent": "io-upstream-check"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        if method == "POST" and path == "/labels" and e.code == 422:
            return None
        raise
    return json.loads(data) if data else None


def sync_issue():
    keys = sorted(k for k, s, t in findings)
    open_issues = api("GET", "/issues?state=open&labels=%s&per_page=10" % LABEL)
    issue = open_issues[0] if open_issues else None
    prev = []
    if issue:
        m = re.search(r"<!-- keys\n(.*?)\n-->", issue["body"] or "", re.S)
        prev = m.group(1).splitlines() if m else []
    if not keys:
        if issue:
            api("POST", "/issues/%d/comments" % issue["number"], {"body": "Nothing left to do upstream."})
            api("PATCH", "/issues/%d" % issue["number"], {"state": "closed"})
        print("issue: nothing to report")
        return
    title = "Upstream check: %d to look at" % len(keys)
    body = ("Found by the scheduled upstream check (every 8 hours). The issue stays open while anything "
            "is left and closes itself when everything is taken care of.\n\n" + report() + HOWTO
            + "\n<!-- keys\n" + "\n".join(keys) + "\n-->\n")
    if not issue:
        api("POST", "/labels", {"name": LABEL, "color": "d4c5f9", "description": "Found by ci/upstream-check.py"})
        issue = api("POST", "/issues", {"title": title, "body": body, "labels": [LABEL]})
        print("issue: opened #%d" % issue["number"])
        return
    new = [k for k in keys if k not in prev]
    if body != issue["body"] or title != issue["title"]:
        api("PATCH", "/issues/%d" % issue["number"], {"title": title, "body": body})
    if new:
        lines = [t for k, s, t in findings if k in new]
        api("POST", "/issues/%d/comments" % issue["number"],
            {"body": "New since the last check:\n\n" + "\n".join("- " + t for t in lines)})
    print("issue: #%d updated, %d new" % (issue["number"], len(new)))


def main():
    for name, check in (("valve", check_valve), ("overlays", check_overlays), ("watch", check_watch),
                        ("kernel", check_kernel), ("manager", check_manager)):
        try:
            check()
        except Exception as e:  # one broken source must not hide the others
            add("error:" + name, "Errors", "check `%s` failed: %s" % (name, str(e)[:200]))
    text = report() if findings else "Nothing to do.\n\n" + report()
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("## Upstream check\n\n" + text)
    if "--issue" in sys.argv:
        sync_issue()


if __name__ == "__main__":
    main()
