"""Render the moving part of the flush (the bowl box) for a range of frames. Resumable: skips frames that exist.
  blender -b flush/toilet-flush.blend --python flush/scripts/f20_render_crops.py -- OUTDIR SAMPLES FIRST LAST
Each output is a 360 x 332 PNG (the box in f16_final_look.py); composite it over the static background with f21_compose.sh.
"""
import bpy, sys, os, time
exec(open("C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/scripts/f16_final_look.py").read())

argv = sys.argv[sys.argv.index("--") + 1:]
outdir, samples, first, last = argv[0], int(argv[1]), int(argv[2]), int(argv[3])
os.makedirs(outdir, exist_ok=True)
apply(samples)
set_box()
sc = bpy.context.scene
for f in range(first, last + 1):
    path = os.path.join(outdir, "crop_%04d.png" % f)
    if os.path.exists(path):
        continue
    t = time.time()
    sc.frame_set(f)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED frame %d in %.0f s" % (f, time.time() - t), flush=True)
