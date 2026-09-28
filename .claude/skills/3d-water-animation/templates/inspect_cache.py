"""Inspect the baked fluid mesh: vertex counts and bounds per frame (read-only)."""
import bpy

sc = bpy.context.scene
dom = bpy.data.objects["Flush_Domain"]
for f in [1, 5, 10, 16, 20, 30, 40, 45, 50, 60, 80, 100, 130, 140, 160]:
    sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = dom.evaluated_get(dg)
    me = ev.to_mesh()
    n = len(me.vertices)
    if n:
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        print("frame %3d verts %7d  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % (f, n, min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    else:
        print("frame %3d verts 0" % f)
    ev.to_mesh_clear()
ds = dom.modifiers["Fluid"].domain_settings
print("domain: res", ds.resolution_max, "cell_size", tuple(ds.cell_size), "domain_resolution", tuple(ds.domain_resolution), "flip", ds.use_flip_particles, "mesh", ds.use_mesh)
print("baked data", ds.has_cache_baked_data, "mesh", ds.has_cache_baked_mesh)
print("domain obj loc", tuple(dom.location), "scale", tuple(dom.scale), "dims", tuple(dom.dimensions))
