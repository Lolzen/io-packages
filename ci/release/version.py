#!/usr/bin/env python3
"""version.py - the next Io release from srcpkgs/io-release/template.

  version.py 0.0.1|0.1            print the next release as KEY=VALUE lines
  version.py 0.0.1|0.1 --apply    also write it into the template

Rules (wiki: Building, Release versions): 0.0.1 steps (0.8 -> 0.8.1 ->
0.8.2), a 0.1 step for a larger change (0.8.2 -> 0.9, 0.9 -> 0.10; the
middle number goes on past 9). The stage word of _name stays ("Beta").
_build is like SteamOS's BUILD_ID: the UTC date and a counter for that day.
The revision goes back to 1.
"""
import datetime
import os
import re
import sys

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "srcpkgs", "io-release", "template")


def get(text, name):
    m = re.search(r'^%s="?([^"\n]*)"?$' % name, text, re.M)
    if not m:
        sys.exit("version.py: no %s in the template" % name)
    return m.group(1)


def put(text, name, value, quote):
    v = '"%s"' % value if quote else value
    return re.sub(r"^%s=.*$" % name, "%s=%s" % (name, v), text, count=1, flags=re.M)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("0.0.1", "0.1"):
        sys.exit("usage: version.py 0.0.1|0.1 [--apply]")
    bump = sys.argv[1]
    text = open(TEMPLATE).read()
    old = get(text, "version")
    old_name = get(text, "_name")
    old_build = get(text, "_build")

    parts = [int(x) for x in old.split(".")]
    if len(parts) not in (2, 3):
        sys.exit("version.py: unexpected version %s" % old)
    if bump == "0.0.1":
        new = parts[:2] + [parts[2] + 1 if len(parts) == 3 else 1]
    else:
        new = [parts[0], parts[1] + 1]
    new = ".".join(str(x) for x in new)

    stage = old_name.rsplit(" ", 1)[0] if " " in old_name else old_name
    name = "%s %s" % (stage, new)
    today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d")
    day, _, count = old_build.partition(".")
    build = "%s.%d" % (today, int(count or 0) + 1 if day == today else 1)
    tag = "%s-%s" % (stage.lower().replace(" ", "-"), new)

    out = {"old_version": old, "old_name": old_name, "version": new, "name": name,
           "build": build, "tag": tag, "title": "Io " + name}
    for k, v in out.items():
        print("%s=%s" % (k, v))

    if "--apply" in sys.argv:
        text = put(text, "version", new, False)
        text = put(text, "revision", "1", False)
        text = put(text, "_name", name, True)
        text = put(text, "_build", build, False)
        open(TEMPLATE, "w").write(text)


if __name__ == "__main__":
    main()
