#!/usr/bin/env python3
"""Lays screenshots side by side for review: python3 tool/visual_sheet.py
<out.png> <a.png> [b.png ...] [--gray] [--height N].

Only a viewing aid (needs Pillow); the individual PNGs and their manifest
remain the evidence. --gray drops colour to check hierarchy without it."""
import sys
from PIL import Image, ImageDraw

args = sys.argv[1:]
gray = '--gray' in args
height = 900
if '--height' in args:
    height = int(args[args.index('--height') + 1])
    del args[args.index('--height'):args.index('--height') + 2]
args = [a for a in args if a != '--gray']
out, files = args[0], args[1:]
tiles = []
for path in files:
    image = Image.open(path).convert('RGB')
    image = image.resize((round(image.width * height / image.height), height))
    if gray:
        image = image.convert('L').convert('RGB')
    tiles.append((path.rsplit('/', 1)[-1], image))
gap, label = 12, 22
sheet = Image.new('RGB', (sum(t.width for _, t in tiles) + gap * (len(tiles) + 1),
                          height + label + gap * 2), (120, 120, 120))
draw = ImageDraw.Draw(sheet)
x = gap
for name, tile in tiles:
    draw.text((x, 4), name, fill=(255, 255, 255))
    sheet.paste(tile, (x, label))
    x += tile.width + gap
sheet.save(out)
