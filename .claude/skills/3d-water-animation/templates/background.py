"""Render the static full-frame background (everything except the moving water) of the flush shot.
  blender -b flush/toilet-flush.blend --python flush/scripts/f17_background.py -- OUT.png WIDTH SAMPLES [FRAME]
"""
import bpy, sys, os
exec(open("C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/scripts/f16_final_look.py").read())

argv = sys.argv[sys.argv.index("--") + 1:]
out, width, samples = argv[0], int(argv[1]), int(argv[2])
frame = int(argv[3]) if len(argv) > 3 else 1
apply(samples)
clear_box()
sc = bpy.context.scene
sc.render.resolution_x = width
sc.render.resolution_y = int(width * 9 / 16)
sc.frame_set(frame)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out, sc.render.resolution_x, sc.render.resolution_y)
