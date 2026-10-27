#!/usr/bin/env python3
"""Deterministic assets and preview; no AI imagery. Requires Pillow + numpy."""
from pathlib import Path
import argparse
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "theme/io-torus"
NATIVE = 384
COUNT = 120
SEGMENTS = 48
JUPITER_HOURS = 9.925
IO_HOURS = 42.459
JUPITER_SECONDS = 8.0
TORUS_FACTOR = 0.985  # illustrative slight subcorotation, not an exact measurement
TAU = math.tau


def rgba_array(rgb, alpha):
    result = np.dstack((np.clip(rgb, 0, 255), np.clip(alpha, 0, 255))).astype(np.uint8)
    return Image.fromarray(result)


def planet(phase):
    # Orthographic sphere: longitude moves, latitude bands stay horizontal.
    size, aa = 160, 3
    yy, xx = np.mgrid[:size * aa, :size * aa]
    nx = ((xx + .5) / aa - size / 2) / 78
    ny = ((yy + .5) / aa - size / 2) / 78
    mask = nx * nx + ny * ny <= 1
    z = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    longitude = np.arctan2(nx, z) - phase
    latitude = np.arcsin(np.clip(ny, -1, 1))
    original_y = 128 + 52 * ny + .38 * np.cos(longitude * 4 + latitude * 9)
    rgb = np.zeros((*nx.shape, 3)) + (122, 92, 66)
    for top, bottom, color in [(90, 99, (160, 122, 88)), (108, 122, (150, 112, 79)),
                               (132, 140, (171, 133, 96)), (150, 163, (141, 104, 73))]:
        rgb[(original_y >= top) & (original_y < bottom)] = color
    # Map the original red ellipse onto a sphere; the back is naturally hidden.
    spot_lon = math.asin((25 / 52) / math.sqrt(1 - (10 / 52) ** 2))
    dlon = np.arctan2(np.sin(longitude - spot_lon), np.cos(longitude - spot_lon))
    dlat = latitude - math.asin(-10 / 52)
    spot = (dlon / .315) ** 2 + (dlat / .139) ** 2 < 1
    rgb[spot] = (196, 100, 58)
    shade = .91 + .09 * z + .018 * np.sin(longitude * 3 + latitude * 8)
    rgb *= shade[..., None]
    return rgba_array(rgb, mask * 255).resize((size, size), Image.Resampling.LANCZOS)


def ring_image():
    aa = 3
    im = Image.new("RGBA", (NATIVE * aa, NATIVE * aa))
    d = ImageDraw.Draw(im)
    c, r, w = 192 * aa, 144 * aa, 16.5 * aa
    # Geometry is exactly the SVG ring scaled by 1.5.
    d.ellipse((c-r-w/2, c-r-w/2, c+r+w/2, c+r+w/2), fill="#c8761e")
    d.ellipse((c-r+w/2, c-r+w/2, c+r-w/2, c+r-w/2), fill=(0, 0, 0, 0))
    return im.resize((NATIVE, NATIVE), Image.Resampling.LANCZOS)


def segment_image(index):
    # Each patch follows the ring arc. Smooth overlap prevents visible seams.
    size, aa = 36, 3
    theta = TAU * index / SEGMENTS
    cx = 192 - 144 * math.sin(theta)
    cy = 192 - 144 * math.cos(theta)
    yy, xx = np.mgrid[:size * aa, :size * aa]
    x = (xx + .5) / aa - size / 2 + cx - 192
    y = (yy + .5) / aa - size / 2 + cy - 192
    radius = np.hypot(x, y)
    angle = np.arctan2(-x, -y)
    da = np.arctan2(np.sin(angle-theta), np.cos(angle-theta))
    angular = np.maximum(0, 1 - np.abs(da) / (TAU / SEGMENTS))
    radial = np.clip((8.25 - np.abs(radius-144)) * 2, 0, 1)
    rgb = np.zeros((*radius.shape, 3)) + (242, 177, 52)
    return rgba_array(rgb, 255 * angular * radial).resize((size, size), Image.Resampling.LANCZOS)


def io_image():
    aa, size = 3, 44
    im = Image.new("RGBA", (size*aa, size*aa))
    ImageDraw.Draw(im).ellipse((aa, aa, 43*aa-1, 43*aa-1), fill="#f2b134")
    return im.resize((size, size), Image.Resampling.LANCZOS)


def make_assets():
    ASSETS.mkdir(parents=True, exist_ok=True)
    ring_image().save(ASSETS / "torus.png", optimize=True)
    io_image().save(ASSETS / "io.png", optimize=True)
    for i in range(COUNT):
        planet(TAU*i/COUNT).save(ASSETS / f"jupiter-{i}.png", optimize=True)
    for i in range(SEGMENTS):
        segment_image(i).save(ASSETS / f"plasma-{i}.png", optimize=True)


class Preview:
    def __init__(self, width=1280, height=800):
        self.width, self.height = width, height
        self.size = min(384, int(min(width, height)*.40))
        self.scale = self.size/NATIVE
        self.center = (width/2, height/2)
        self.ring = self.load("torus.png")
        self.io = self.load("io.png")
        self.planets = [self.load(f"jupiter-{i}.png") for i in range(COUNT)]
        self.segments = [self.load(f"plasma-{i}.png") for i in range(SEGMENTS)]

    def load(self, name):
        im = Image.open(ASSETS/name).convert("RGBA")
        return im.resize((int(im.width*self.scale), int(im.height*self.scale)), Image.Resampling.LANCZOS)

    def frame(self, seconds):
        canvas = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 255))
        cx, cy = self.center
        def paste(im, x=cx, y=cy, opacity=1):
            if opacity < 1:
                im = im.copy()
                im.putalpha(im.getchannel("A").point(lambda a: round(a*opacity)))
            canvas.alpha_composite(im, (round(x-im.width/2), round(y-im.height/2)))
        fade = min(1, seconds/.35)
        paste(self.ring, opacity=fade)
        p = TAU*seconds/JUPITER_SECONDS*TORUS_FACTOR
        r = 144*self.scale
        for i, im in enumerate(self.segments):
            theta = TAU*i/SEGMENTS
            wave = (.5+.5*math.cos(theta-p))**6
            secondary = (.5+.5*math.cos(theta-p-math.pi))**6
            paste(im, cx-r*math.sin(theta), cy-r*math.cos(theta), fade*(.55*wave+.16*secondary))
        index = int(seconds/JUPITER_SECONDS*COUNT) % COUNT
        paste(self.planets[index], opacity=fade)
        io_phase = TAU*seconds/(JUPITER_SECONDS*IO_HOURS/JUPITER_HOURS)
        paste(self.io, cx-r*math.sin(io_phase), cy-r*math.cos(io_phase), fade)
        return canvas.convert("RGB")


def make_preview(output, seconds=35, fps=20):
    import subprocess
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    renderer = Preview()
    # Video samples the same callback clock and asset selection as the theme.
    process = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pixel_format", "rgb24",
                                "-video_size", "1280x800", "-framerate", str(fps), "-i", "-", "-an",
                                "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p",
                                "-movflags", "+faststart", str(output/"io-torus-preview.mp4")], stdin=subprocess.PIPE)
    gif_frames = []
    for i in range(int(seconds*fps)):
        t = math.floor(i/fps*30)/30
        frame = renderer.frame(t)
        process.stdin.write(frame.tobytes())
        if i % 2 == 0:
            gif_frames.append(frame.resize((640, 400), Image.Resampling.LANCZOS))
    process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError("ffmpeg failed")
    # One Io orbit plus a fraction. Each body's phase is continuous throughout.
    # A repeat has an intentional reset; in Plymouth there is no master loop reset.
    gif_frames[0].save(output/"io-torus-preview.gif", save_all=True,
                       append_images=gif_frames[1:], duration=100, loop=0, optimize=True)
    renderer.frame(1).save(output/"io-torus-still.png")
    tiles = Image.new("RGB", (1280, 800))
    for i, t in enumerate([.5, 2, 4, 6]):
        tiles.paste(renderer.frame(t).resize((640, 400)), ((i%2)*640, (i//2)*400))
    tiles.save(output/"contact-sheet.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--assets-only", action="store_true")
    args = parser.parse_args()
    make_assets()
    if args.preview and not args.assets_only:
        make_preview(args.preview)
