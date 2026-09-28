"""Build the flush simulation scene from the toilet environment (does NOT modify the source .blend).
Run:  blender -b toilet-environment.blend --python flush/scripts/f10_build_scene.py
Writes flush/toilet-flush.blend (in METRES, Z-up; source is in cm). Idempotent (always rebuilds from the source).
Env: FLUSH_RES = fluid domain resolution (default 64 for tests, ~160 for the final).
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

OUT = "C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/toilet-flush.blend"
FPS = 30
END = 165

# All numbers below are in METRES after the conversion. Bowl axis (from the ray-cast map): x 1.50, y 2.11.
CX, CY = 1.50, 2.11
RESOLUTION = int(os.environ.get("FLUSH_RES", "64"))

sc = bpy.context.scene

# ---------------------------------------------------------------- 1. prune to what the shot needs
for coll_name in ["Collision", "Review"]:
    c = bpy.data.collections.get(coll_name)
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
center_cm = Vector((150.0, 211.0, 0.0))
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    in_shell = any(c.name in ("Shell", "Lighting") for c in o.users_collection)
    if in_shell:
        continue
    d = Vector(o.matrix_world.translation) - center_cm
    d.z = 0
    if d.length > 320.0:
        bpy.data.objects.remove(o, do_unlink=True)
# the seat lid is hidden while a toilet is in use (as in the game)
lid = bpy.data.objects.get("SM_Toilet_R1_01_Lid")
if lid:
    bpy.data.objects.remove(lid, do_unlink=True)
print("pruned, remaining objects:", len(bpy.data.objects))

# ---------------------------------------------------------------- 2. cm -> metres (bake the scale into the meshes)
S = Matrix.Scale(0.01, 4)
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    mw = o.matrix_world.copy()
    if o.data.users > 1:
        o.data = o.data.copy()
    o.data.transform(S @ mw)
    if (S @ mw).determinant() < 0:
        o.data.flip_normals()
    o.parent = None
    o.matrix_world = Matrix.Identity(4)
sc.unit_settings.system = 'METRIC'
sc.unit_settings.scale_length = 1.0
sc.unit_settings.length_unit = 'METERS'
print("converted to metres")

CERAMIC = bpy.data.materials.get("M_Ceramic")


def make_obj(name, me, mat=None):
    o = bpy.data.objects.new(name, me)
    sc.collection.objects.link(o)
    if mat:
        o.data.materials.append(mat)
    return o


def spin_mesh(name, profile, closed):
    """Spin an (r, z) profile around the bowl axis into a mesh."""
    bm = bmesh.new()
    verts = [bm.verts.new((CX + r, CY, z)) for r, z in profile]
    n = len(verts)
    edges = [bm.edges.new((verts[i], verts[(i + 1) % n])) for i in range(n if closed else n - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(CX, CY, 0.0), axis=(0, 0, 1), angle=math.tau, steps=64, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


# ---------------------------------------------------------------- 3. physics proxy of the bowl (hidden in the render)
# cavity profile measured from the ray-cast map (r, z in metres): rim wall, funnel, then a sump with a small drain
CAVITY = [(0.173, 0.48), (0.170, 0.345), (0.165, 0.34), (0.150, 0.33), (0.135, 0.31), (0.120, 0.28),
          (0.105, 0.26), (0.090, 0.23), (0.080, 0.215), (0.070, 0.185), (0.055, 0.160), (0.038, 0.143),
          (0.028, 0.135), (0.025, 0.125), (0.025, 0.07)]
solid_profile = CAVITY + [(0.30, 0.07), (0.30, 0.48)]
proxy = make_obj("Sim_Bowl", spin_mesh("Sim_Bowl_mesh", solid_profile, True))
proxy.hide_render = True
proxy.display_type = 'WIRE'

# visible sump: a thin ceramic bowl that closes the hole under the funnel (the real toilet mesh has a big open hole)
SUMP = [(0.081, 0.216), (0.070, 0.186), (0.055, 0.161), (0.038, 0.144), (0.028, 0.136), (0.0, 0.135)]
sump = make_obj("Vis_Sump", spin_mesh("Vis_Sump_mesh", SUMP, False), CERAMIC)
for p in sump.data.polygons:
    p.use_smooth = True

# plug: seals the drain (collision effector, animated open for the flush)
bpy.ops.mesh.primitive_cylinder_add(radius=0.027, depth=0.012, location=(CX, CY, 0.129), vertices=24)
plug = bpy.context.object
plug.name = "Sim_Plug"
plug.hide_render = True

# outflow: deletes fluid that leaves through the drain
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(CX, CY, 0.04))
outflow = bpy.context.object
outflow.name = "Sim_Outflow"
outflow.scale = (0.40, 0.40, 0.06)   # the whole bottom slab of the domain (z 0.01-0.07): nothing may pool on the floor
outflow.hide_render = True

# initial water body (rest level about 0.295 m)
bpy.ops.mesh.primitive_cylinder_add(radius=0.165, depth=0.185, location=(CX, CY, 0.2275), vertices=48)   # top at 0.32: settles to about 0.295
pool = bpy.context.object
pool.name = "Sim_Pool"
pool.hide_render = True


def add_emitter(name, angle, speed_t, speed_down, size=(0.018, 0.028, 0.02), r=0.158, z=0.462):
    """An inflow emitter just under the rim, aimed along the wall (tangent) and slightly down."""
    x = CX + r * math.cos(angle)
    y = CY + r * math.sin(angle)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z))
    e = bpy.context.object
    e.name = name
    e.scale = size
    e.rotation_euler = (0, 0, angle)
    e.hide_render = True
    vel = Vector((-math.sin(angle), math.cos(angle), 0.0)) * speed_t + Vector((0, 0, -speed_down))
    return e, tuple(vel)


jets = [add_emitter("Sim_Jet%02d" % i, math.tau * i / 24, 0.9, 0.25, size=(0.010, 0.026, 0.012), r=0.160) for i in range(24)]
refill = [add_emitter("Sim_Refill%02d" % i, math.tau * (i + 0.5) / 4, 0.6, 0.6) for i in range(4)]

# domain
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(CX, CY, 0.30))
dom = bpy.context.object
dom.name = "Flush_Domain"
dom.scale = (0.40, 0.40, 0.58)   # a size-1 cube: edges 0.40 x 0.40 x 0.58 m, z from 0.01 to 0.59


# ---------------------------------------------------------------- 4. fluid setup
def fluid(obj, kind):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_add(type='FLUID')
    m = obj.modifiers[-1]
    m.fluid_type = kind
    return m


ds = fluid(dom, 'DOMAIN').domain_settings
ds.domain_type = 'LIQUID'
ds.resolution_max = RESOLUTION
ds.use_mesh = True
ds.mesh_scale = 2
ds.use_adaptive_timesteps = True
ds.timesteps_max = 6
ds.cache_type = 'ALL'
ds.cache_frame_start = 1
ds.cache_frame_end = END
ds.cache_directory = "C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/cache"
ds.use_flip_particles = True
ds.flip_ratio = 0.94
ds.particle_number = 3
ds.mesh_smoothen_pos = 2
ds.mesh_smoothen_neg = 1

es = fluid(proxy, 'EFFECTOR').effector_settings
es.effector_type = 'COLLISION'
es = fluid(plug, 'EFFECTOR').effector_settings
es.effector_type = 'COLLISION'
fs = fluid(pool, 'FLOW').flow_settings
fs.flow_type = 'LIQUID'
fs.flow_behavior = 'GEOMETRY'
fs.use_initial_velocity = False
fs = fluid(outflow, 'FLOW').flow_settings
fs.flow_type = 'LIQUID'
fs.flow_behavior = 'OUTFLOW'


def make_inflow(obj, vel, on_frame, off_frame):
    fs = fluid(obj, 'FLOW').flow_settings
    fs.flow_type = 'LIQUID'
    fs.flow_behavior = 'INFLOW'
    fs.use_initial_velocity = True
    fs.velocity_coord = vel
    for f, v in [(1, False), (on_frame, True), (off_frame, False)]:
        fs.use_inflow = v
        fs.keyframe_insert(data_path="use_inflow", frame=f)


# jets on from frame 16 (0.5 s) to 47 (1.55 s); refill on from 130 to 158
for e, vel in jets:
    make_inflow(e, vel, 16, 44)
for e, vel in refill:
    make_inflow(e, vel, 130, 158)
# plug open (no collision) from frame 40 (1.33 s) to 134 (4.47 s)
pe = plug.modifiers["Fluid"].effector_settings
for f, v in [(1, True), (40, False), (134, True)]:
    pe.use_effector = v
    pe.keyframe_insert(data_path="use_effector", frame=f)
# constant interpolation for all the boolean keys
for ob in bpy.data.objects:
    ad = ob.animation_data
    if ad and ad.action:
        for layer in ad.action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = 'CONSTANT'

# ---------------------------------------------------------------- 5. water material on the domain (the baked surface mesh)
wm = bpy.data.materials.new("M_FlushWater")
wm.use_nodes = True
nt = wm.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Base Color"].default_value = (0.90, 0.97, 1.0, 1.0)
bsdf.inputs["Roughness"].default_value = 0.015
bsdf.inputs["IOR"].default_value = 1.333
bsdf.inputs["Transmission Weight"].default_value = 1.0
vol = nt.nodes.new("ShaderNodeVolumeAbsorption")
vol.inputs["Color"].default_value = (0.75, 0.92, 0.95, 1.0)
vol.inputs["Density"].default_value = 6.0
nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
dom.data.materials.append(wm)

# ---------------------------------------------------------------- 6. camera (the game's flush camera, metres)
cam_data = bpy.data.cameras.new("CAM_Flush")
cam_data.sensor_fit = 'VERTICAL'
cam_data.sensor_height = 24.0
cam_data.lens = 12.0 / math.tan(math.radians(35.0))
cam_data.clip_start = 0.02
cam_data.clip_end = 20.0
cam = bpy.data.objects.new("CAM_Flush", cam_data)
sc.collection.objects.link(cam)
cam.location = (1.50, 1.55, 1.10)
cam.rotation_euler = (math.radians(90.0 - 57.3), 0.0, 0.0)
sc.camera = cam

sc.frame_start, sc.frame_end = 1, END
sc.render.fps = FPS
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.use_denoising = True

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT, "objects", len(bpy.data.objects), "res", RESOLUTION)
