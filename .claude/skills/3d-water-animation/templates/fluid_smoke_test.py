"""Tiny liquid bake to check that Mantaflow works headless in Blender 5.2 and how long it takes."""
import bpy, time, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.frame_start, sc.frame_end = 1, 12
sc.render.fps = 30

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
dom = bpy.context.object; dom.name = "Domain"; dom.scale = (0.4, 0.4, 0.5)
bpy.ops.object.modifier_add(type='FLUID'); dom.modifiers["Fluid"].fluid_type = 'DOMAIN'
ds = dom.modifiers["Fluid"].domain_settings
ds.domain_type = 'LIQUID'
ds.resolution_max = 48
ds.cache_directory = "//_smoke_cache"

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.25))
fl = bpy.context.object; fl.name = "Water"; fl.scale = (0.2, 0.2, 0.2)
bpy.ops.object.modifier_add(type='FLUID'); fl.modifiers["Fluid"].fluid_type = 'FLOW'
fs = fl.modifiers["Fluid"].flow_settings
fs.flow_type = 'LIQUID'; fs.flow_behavior = 'GEOMETRY'
bpy.ops.wm.save_as_mainfile(filepath="C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/_smoke.blend")
bpy.context.view_layer.objects.active = dom
dom.select_set(True)
t = time.time()
bpy.ops.fluid.bake_data()
print("BAKE SECONDS", round(time.time() - t, 1))
