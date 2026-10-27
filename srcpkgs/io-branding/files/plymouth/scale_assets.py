#!/usr/bin/env python3
"""Scale the boot splash sprites from build_assets.py (drawn for a 384 pixel
logo) to the size the splash shows them at, so that Plymouth need not scale
them at boot: scaling 170 images in the script takes about a second, during
which the splash stays black and Plymouth answers no one.

usage: scale_assets.py <dir> <logo size>"""
import sys
from pathlib import Path
from PIL import Image

NATIVE = 384

directory = Path(sys.argv[1])
size = int(sys.argv[2])
for path in sorted(directory.glob("*.png")):
    with Image.open(path) as im:
        im.load()
    # As the script did: whole pixels, rounded down
    width = int(im.width * size / NATIVE)
    height = int(im.height * size / NATIVE)
    im.resize((width, height), Image.Resampling.LANCZOS).save(path, optimize=True)
