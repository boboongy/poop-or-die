"""Compare mean colours of static regions between the Blender background and a Godot screenshot.
  blender -b --python flush/scripts/f18_color_compare.py -- BLENDER.png GODOT.png
Regions are normalised (x0, x1, y0, y1) from the top-left, chosen to avoid the bowl, the HUD text and the trash bin.
"""
import bpy, sys

argv = sys.argv[sys.argv.index("--") + 1:]
REGIONS = {
    "left wall tiles": (0.05, 0.22, 0.12, 0.40),
    "floor front": (0.42, 0.58, 0.82, 0.96),
    "right partition": (0.86, 0.96, 0.25, 0.60),
    "back wall tiles": (0.34, 0.42, 0.10, 0.22),
    "tank": (0.44, 0.56, 0.03, 0.14),
    "rim front": (0.45, 0.55, 0.53, 0.58),
}

def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = list(img.pixels)
    return w, h, px

def mean(w, h, px, box):
    x0, x1, y0, y1 = box
    r = g = b = 0.0
    n = 0
    for yy in range(int(y0 * h), int(y1 * h), 2):
        yb = h - 1 - yy   # Blender images are bottom-up
        for xx in range(int(x0 * w), int(x1 * w), 2):
            i = (yb * w + xx) * 4
            r += px[i]; g += px[i + 1]; b += px[i + 2]; n += 1
    return (r / n, g / n, b / n)

blender = load(argv[0])
godot = load(argv[1])
gains = []
for name, box in REGIONS.items():
    mb = mean(*blender, box)
    mg = mean(*godot, box)
    gain = tuple(g / b if b > 1e-4 else 0 for g, b in zip(mg, mb))
    gains.append(gain)
    print("%-16s blender %s  godot %s  gain %s" % (name, tuple(round(v, 3) for v in mb), tuple(round(v, 3) for v in mg), tuple(round(v, 2) for v in gain)))
avg = tuple(sum(g[i] for g in gains) / len(gains) for i in range(3))
print("AVERAGE GAIN (r,g,b) to multiply the Blender image by:", tuple(round(v, 3) for v in avg))
