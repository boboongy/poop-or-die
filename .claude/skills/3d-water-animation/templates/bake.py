"""Bake the flush fluid simulation (data, then the surface mesh) headless.
  blender -b flush/toilet-flush.blend --python flush/scripts/f12_bake.py -- [END_FRAME]
Writes the cache next to the .blend (flush/cache). Does not save the .blend.
"""
import bpy, sys, time

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sc = bpy.context.scene
dom = bpy.data.objects["Flush_Domain"]
ds = dom.modifiers["Fluid"].domain_settings
if argv:
    ds.cache_frame_end = int(argv[0])
print("BAKE: res", ds.resolution_max, "frames", ds.cache_frame_start, ds.cache_frame_end, "cache", bpy.path.abspath(ds.cache_directory))
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = dom
dom.select_set(True)
t = time.time()
bpy.ops.fluid.bake_data()
print("DATA BAKED in %.0f s" % (time.time() - t))
t = time.time()
bpy.ops.fluid.bake_mesh()
print("MESH BAKED in %.0f s" % (time.time() - t))
