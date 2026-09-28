"""Ray-cast down into the bowl to map the cavity floor (read-only). Prints an ASCII height map (cm)."""
import bpy, math
from mathutils import Vector
o = bpy.data.objects["SM_Toilet_R1_01_Body"]
inv = o.matrix_world.inverted()
cx, cy = 150.0, 211.0
print("rows = Y (top row = +Y, toward the tank), cols = X. value = z of the first surface hit in cm (blank = no hit)")
for j in range(24, -25, -2):
    y = cy + j * 0.75
    row = ""
    for i in range(-24, 25, 2):
        x = cx + i * 0.75
        o_local = inv @ Vector((x, y, 70.0))
        d_local = (inv.to_3x3() @ Vector((0, 0, -1))).normalized()
        ok, loc, nrm, idx = o.ray_cast(o_local, d_local)
        if ok:
            z = (o.matrix_world @ loc).z
            row += "%3d " % round(z)
        else:
            row += " .  "
    print("y=%6.1f %s" % (y, row))
# is the mesh closed?
import bmesh
bm = bmesh.new(); bm.from_mesh(o.data)
non_manifold = [e for e in bm.edges if not e.is_manifold]
print("edges", len(bm.edges), "non-manifold edges", len(non_manifold), "faces", len(bm.faces))
bm.free()
