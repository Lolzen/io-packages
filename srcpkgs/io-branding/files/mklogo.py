#!/usr/bin/env python3
import math

ROWS = 17
ASPECT = 2.0
JUPITER = 0.55
IO_ROW = 2
import os
COLOR = os.environ.get("COLOR", "1") != "0"

RING_CH_TOP = "="
RING_CH_BOT = "="
BAND_CH = "~"

WORDMARK = [
    "   ,####   ,QQQ, ",
    "   ####   QQ' 'QQ",
    "  ####    QQ, ,QQ",
    " #####     'QQQ' ",
]

MARK = {1: "$2", 2: "$3", 3: "$1", 4: "$1"}

cols = int(ROWS * ASPECT)
cx, cy = (cols - 1) / 2, (ROWS - 1) / 2
rx, ry = cx, cy

grid = [[" "] * cols for _ in range(ROWS)]
layer = [[0] * cols for _ in range(ROWS)]

def put(row, col, ch, lay):
    if 0 <= row < ROWS and 0 <= col < cols:
        grid[row][col] = ch
        layer[row][col] = lay

def ring(r_x, r_y):
    for row in range(ROWS):
        dy = (row - cy) / r_y
        if abs(dy) > 1:
            continue
        off = r_x * math.sqrt(1 - dy * dy)
        prev = 0.0
        if row > 0:
            d2 = (row - 1 - cy) / r_y
            prev = r_x * math.sqrt(max(0, 1 - d2 * d2))
        lo, hi = sorted((abs(prev), off))
        ch = RING_CH_TOP if row < cy else RING_CH_BOT
        for x in range(cols):
            d = abs(x - cx)
            if lo - 1.5 <= d <= hi + 1.0:
                put(row, x, ch, 1)

def disc(r_x, r_y):
    for row in range(ROWS):
        dy = (row - cy) / r_y
        if abs(dy) > 1:
            continue
        off = r_x * math.sqrt(1 - dy * dy)
        for x in range(cols):
            if abs(x - cx) <= off:
                put(row, x, BAND_CH, 2)

ring(rx, ry)
disc(rx * JUPITER, ry * JUPITER)

wm_h = len(WORDMARK)
wm_w = max(len(l) for l in WORDMARK)
start_row = (ROWS - wm_h) // 2
start_col = int(cx - wm_w / 2)

for r, line in enumerate(WORDMARK):
    for c in range(wm_w):
        ch = line[c] if c < len(line) else " "
        if ch == " ":
            continue
        put(start_row + r, start_col + c, ch, 3)

dy = (IO_ROW - cy) / ry
put(IO_ROW, int(cx + rx * math.sqrt(1 - dy * dy)), "o", 4)

for r in range(ROWS):
    out, cur = [], None
    for c in range(cols):
        ch = grid[r][c]
        if ch == " ":
            out.append(" ")
            continue
        lay = layer[r][c]
        if COLOR and lay != cur:
            out.append(MARK[lay])
            cur = lay
        out.append(ch)
    print("".join(out).rstrip())