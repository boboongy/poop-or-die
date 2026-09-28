"""Diagnostic renders: a bigger, brighter crop around the bowl so the water can be judged.
  blender -b flush/toilet-flush.blend --python flush/scripts/f14_diag.py -- OUTDIR SAMPLES EXPOSURE FRAME [FRAME ...]
Not for the final video (exposure is boosted). Does not save the .blend.
"""
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
outdir, samples, exposure = argv[0], int(argv[1]), float(argv[2])
frames = [int(f) for f in argv[3:]]
os.makedirs(outdir, exist_ok=True)

sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.render.resolution_percentage = 100
sc.render.use_border = True
sc.render.use_crop_to_border = True
sc.render.border_min_x, sc.render.border_max_x = 0.36, 0.64
sc.render.border_min_y, sc.render.border_max_y = 0.34, 0.80
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = samples
sc.cycles.use_denoising = True
sc.cycles.max_bounces = 12
sc.cycles.transmission_bounces = 12
sc.view_settings.exposure = exposure
sc.render.image_settings.file_format = 'PNG'
for f in frames:
    sc.frame_set(f)
    sc.render.filepath = os.path.join(outdir, "diag_%04d.png" % f)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", sc.render.filepath)
