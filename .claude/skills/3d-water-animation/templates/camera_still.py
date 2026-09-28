"""Render a still from the Godot flush camera into the toilet scene (read-only: the .blend is not saved).
  blender -b ../../toilet-environment.blend --python f01_camera_probe.py -- out.png [samples]
"""
import bpy, math, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[0] if argv else "//flush/renders/f01_probe.png"
samples = int(argv[1]) if len(argv) > 1 else 48

sc = bpy.context.scene
# hide the lid (the game hides it during use)
for n in ["SM_Toilet_R1_01_Lid"]:
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True
        o.hide_viewport = True

# Godot flush camera, in Blender cm (Godot Z = -Blender Y): (150, 155, 110), looks +Y pitched down 57.3 degrees
cam_data = bpy.data.cameras.new("CAM_Flush")
cam_data.sensor_fit = 'VERTICAL'
cam_data.sensor_height = 24.0
cam_data.lens = 12.0 / math.tan(math.radians(35.0))   # 70 degree vertical FOV
cam_data.clip_start = 2.0   # cm
cam_data.clip_end = 500.0
cam = bpy.data.objects.new("CAM_Flush", cam_data)
sc.collection.objects.link(cam)
cam.location = (150.0, 155.0, 110.0)
cam.rotation_euler = (math.radians(90.0 - 57.3), 0.0, 0.0)
sc.camera = cam

sc.render.resolution_x = 640
sc.render.resolution_y = 360
sc.render.resolution_percentage = 100
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = samples
sc.cycles.use_denoising = True
sc.render.image_settings.file_format = 'PNG'
sc.render.filepath = bpy.path.abspath(out)
print("RENDER ->", sc.render.filepath, "samples", samples, "lens", round(cam_data.lens, 2))
bpy.ops.render.render(write_still=True)
print("DONE")
