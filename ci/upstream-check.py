#!/usr/bin/env python3
"""upstream-check.py - what upstream has that Io has not taken yet.

Checks, each finding with a stable key so it is reported once:
  valve      Valve's package listings (pkgcheck.sh) against docs/*-latest.txt;
             a new SteamOS release branch on Valve's mirror
  overlay    each overlay's Void package: new version (patches to check) or
             new revision / io_revision not published in io-repo's current
  watch      Void packages Io waits for (ci/void-watch.txt)
  kernel     kernel.org stable releases of linux-neptune-72's series
  manager    Valve's steamos-manager main against the fork's runit branch;
             the fork's runit against srcpkgs/steamos-manager's _commit

Usage:
  ci/upstream-check.py               print the report
  ci/upstream-check.py --issue       also sync the GitHub issue (Actions:
                                     GITHUB_TOKEN, GITHUB_REPOSITORY)
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import plistlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALVE_SOURCES = "https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/"
VOID_RAW = "https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/{}/template"
IO_REPODATA = "https://github.com/Lolzen/io-repo/releases/download/current/x86_64-repodata"
KERNEL_DIR = "https://cdn.kernel.org/pub/linux/kernel/v{}.x/"
VALVE_MANAGER = "https://gitlab.steamos.cloud/holo/steamos-manager.git"
FORK_MANAGER = "https://github.com/Lolzen/steamos-manager.git"
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
    return [int(x) if x.isdigit() else x for x in re.split(r"[._-]", v)]


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
    release = re.search(r"RELEASE=\$\{RELEASE:-([0-9.]+)\}", read("pkgcheck.sh")).group(1)
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
        for branch in ("jupiter-main", "holo-main", "jupiter-" + release, "holo-" + release):
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
        if vkey(ver) > vkey(release):
            add("valve-branch:" + name, "Valve's packages",
                "new release branch `%s` on Valve's mirror (pkgcheck.sh has RELEASE=%s)" % (name, release))


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


def check_kernel():
    v = template_vars(read("srcpkgs/linux-neptune-72/template"))["version"]
    series = ".".join(v.split(".")[:2])
    listing = fetch(KERNEL_DIR.format(v.split(".")[0]))
    found = set(re.findall(r"patch-(%s\.\d+)\.xz" % re.escape(series), listing))
    newer = sorted((x for x in found if vkey(x) > vkey(v)), key=vkey)
    if newer:
        add("kernel:" + newer[-1], "Kernel",
            "stable **%s** is out, `linux-neptune-72` is on %s (see the wiki's Kernel page)" % (newer[-1], v))


# --- SteamOS Manager ---------------------------------------------------------

def git(*args, cwd=None):
    return subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True, text=True)


def check_manager():
    commit = template_vars(read("srcpkgs/steamos-manager/template"))["_commit"]
    tmp = tempfile.mkdtemp()
    try:
        r = git("clone", "-q", "--bare", "--filter=blob:none", FORK_MANAGER, tmp)
        if r.returncode:
            add("error:fork-clone", "Errors", "cloning the fork failed: " + r.stderr.strip()[:200])
            return
        runit = git("rev-parse", "refs/heads/runit", cwd=tmp).stdout.strip()
        if runit != commit:
            add("manager-template:" + runit, "SteamOS Manager",
                "the fork's `runit` is at **%s**, `srcpkgs/steamos-manager` builds %s (raise the template)"
                % (runit[:9], commit[:9]))
        r = git("ls-remote", VALVE_MANAGER, "refs/heads/main")
        if r.returncode or not r.stdout.strip():
            add("error:valve-gitlab", "Errors", "Valve's GitLab not reachable: " + r.stderr.strip()[:200])
            return
        valve = r.stdout.split()[0]
        contained = git("merge-base", "--is-ancestor", valve, runit, cwd=tmp).returncode == 0
        if not contained:
            add("manager-valve:" + valve, "SteamOS Manager",
                "Valve's `main` is at **%s**, not in the fork's `runit` (rebase the runit commits)" % valve[:9])
    finally:
        shutil.rmtree(tmp)


# --- report and issue ---------------------------------------------------------

SECTIONS = ["SteamOS Manager", "Kernel", "Overlays (Void)", "Waiting for Void", "Valve's packages", "Errors"]

HOWTO = """
<details><summary>How a finding goes away</summary>

- **Valve's packages:** evaluate, then run `./pkgcheck.sh` and commit `docs/` (unimportant packages: `ci/valve-ignore.txt`)
- **New release branch:** raise `RELEASE` in `pkgcheck.sh`
- **Overlays:** raise `base_version` after checking the patches; build and publish to current
- **Waiting for Void:** take the change, then update or remove the line in `ci/void-watch.txt`
- **Kernel:** update `linux-neptune-72`
- **SteamOS Manager:** rebase `runit` onto Valve's main; raise `_commit` in the template
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
    text = report() or "Nothing to do.\n"
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("## Upstream check\n\n" + text)
    if "--issue" in sys.argv:
        sync_issue()


if __name__ == "__main__":
    main()
