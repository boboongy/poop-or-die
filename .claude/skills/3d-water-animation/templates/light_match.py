"""Try a few spot-light setups for the flush shot and print how close each is to the Godot screenshot's colours.
  blender -b flush/toilet-flush.blend --python flush/scripts/f19_light_match.py -- GODOT.png OUTDIR
Targets are the mean colours of static regions of the Godot frame (left wall, floor, right partition, back wall).
"""
import bpy, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1:]
godot_path, outdir = argv[0], argv[1]
os.makedirs(outdir, exist_ok=True)
sc = bpy.context.scene

REGIONS = {
    "left wall": (0.05, 0.22, 0.12, 0.40),
    "floor front": (0.42, 0.58, 0.82, 0.96),
    "right partition": (0.86, 0.96, 0.25, 0.60),
    "back wall": (0.34, 0.42, 0.10, 0.22),
}

def region_means(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = list(img.pixels)
    out = {}
    for name, (x0, x1, y0, y1) in REGIONS.items():
        r = g = b = 0.0; n = 0
        for yy in range(int(y0 * h), int(y1 * h), 2):
            yb = h - 1 - yy
            for xx in range(int(x0 * w), int(x1 * w), 2):
                i = (yb * w + xx) * 4
                r += px[i]; g += px[i + 1]; b += px[i + 2]; n += 1
        out[name] = (r / n, g / n, b / n)
    bpy.data.images.remove(img)
    return out

target = region_means(godot_path)
print("TARGET", {k: tuple(round(v, 2) for v in t) for k, t in target.items()})

sc.render.resolution_x, sc.render.resolution_y = 640, 360
sc.render.resolution_percentage = 100
sc.render.use_border = False
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.cycles.max_bounces = 6
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'None'
sc.view_settings.exposure = 0.0
sc.render.image_settings.file_format = 'PNG'
sc.frame_set(1)
dom = bpy.data.objects["Flush_Domain"]
dom.hide_render = True   # no water needed for the surroundings

# a spot light above the bowl: a pool of light in the middle, dark sides (like the game's ceiling panels)
ld = bpy.data.lights.new("Key", 'SPOT')
key = bpy.data.objects.new("Key", ld)
sc.collection.objects.link(key)
key.location = (1.5, 1.75, 2.5)
key.rotation_euler = (math.radians(12), 0, 0)   # tilt a little toward the bowl (bowl is at y 2.11)
key.visible_camera = False

best = None
for energy in (60.0, 120.0, 240.0):
    for size in (50.0, 75.0):
        for col in ((0.55, 1.0, 0.6),):
            ld.energy = energy
            ld.spot_size = math.radians(size)
            ld.spot_blend = 1.0
            ld.color = col
            name = "e%d_s%d" % (energy, size)
            sc.render.filepath = os.path.join(outdir, name + ".png")
            bpy.ops.render.render(write_still=True)
            got = region_means(sc.render.filepath)
            err = 0.0
            for k in REGIONS:
                for c in range(3):
                    err += (math.log(max(got[k][c], 1e-3)) - math.log(max(target[k][c], 1e-3))) ** 2
            print("%-10s err %.2f  %s" % (name, err, {k: tuple(round(v, 2) for v in got[k]) for k in REGIONS}))
            if best is None or err < best[0]:
                best = (err, name)
print("BEST", best)
