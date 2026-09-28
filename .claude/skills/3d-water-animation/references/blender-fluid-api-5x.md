# Blender 5.2 fluid (Mantaflow) API: facts verified headless (2026-09-20)

Run: `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b file.blend --python script.py -- args`. Args come after `--` (`sys.argv[sys.argv.index("--")+1:]`).
The BlenderMCP addon prints "cannot start server in background mode" and does nothing in `-b`; that is expected, not an error to fix.

## Objects
- Add a fluid role: `bpy.ops.object.modifier_add(type='FLUID')`, then `mod.fluid_type = 'DOMAIN' | 'FLOW' | 'EFFECTOR'`. Make the object active and selected first (`select_all(DESELECT)`, set `view_layer.objects.active`, `select_set(True)`).
- **Domain** `mod.domain_settings`: `domain_type='LIQUID'`, `resolution_max`, `use_mesh=True`, `mesh_scale`, `use_adaptive_timesteps`, `timesteps_max`, `cache_type='ALL'`, `cache_frame_start/end`, `use_flip_particles`, `flip_ratio`, `particle_number`, `mesh_smoothen_pos/neg`.
- **`cache_directory` must be an ABSOLUTE path.** A `//cache` value resolved to the PARENT folder of the .blend (423 MB landed in the wrong place).
- **Flow** `mod.flow_settings`: `flow_type='LIQUID'`, `flow_behavior='GEOMETRY'` (starting water) | `'INFLOW'` | `'OUTFLOW'` (deletes fluid), `use_initial_velocity`, `velocity_coord` (a 3-tuple in world axes), `use_inflow` (boolean, keyframable).
- **Effector** `mod.effector_settings`: `effector_type='COLLISION'`, `use_effector` (boolean, keyframable, used to open a drain plug).
- A cube's `scale` is its FULL edge length when the mesh is a size-1 cube. Domain bounds = the object's bounding box.
- The domain object's own mesh is replaced by the baked surface mesh; assign the water material to the domain.

## Baking
- `bpy.ops.fluid.bake_data()` then `bpy.ops.fluid.bake_mesh()`. **The domain must be the active and selected object or it fails with "Invalid domain".**
- Run them from a background script; the script does not save the .blend, the cache lives in `cache_directory`.
- Check the result without rendering: evaluate the domain at frames and print vertex counts and bounds (`inspect_cache`). Vertex count near a constant and bounds equal to the domain shell on every frame means nothing simulated (wrong domain size).
- Cache size at res 160, 165 frames, 0.40 x 0.40 x 0.58 m: 2.4 GB.

## Keyframes in Blender 5.x
`fs.use_inflow = True; fs.keyframe_insert(data_path="use_inflow", frame=f)` works. Actions are layered now: set interpolation with
`for layer in action.layers: for strip in layer.strips: for cb in strip.channelbags: for fc in cb.fcurves: ...`. `action.fcurves` no longer exists.

## Meshes and units
- The toilet .blend is authored in cm (scene unit scale 0.01). To get metres: `mesh.transform(Matrix.Scale(0.01, 4) @ obj.matrix_world)` per object, flip normals if the determinant is negative, reset the object's matrix; then set the scene unit scale to 1.0.
- Revolve a profile with `bmesh.ops.spin(geom=..., cent=..., axis=(0,0,1), angle=tau, steps=64, use_merge=True)` then `remove_doubles` and `recalc_face_normals`.
- Ray-cast a mesh: `obj.ray_cast(origin_local, direction_local)` (local space; convert with `matrix_world.inverted()`).

## Rendering
- Crop of a frame: `scene.render.use_border = True`, `use_crop_to_border = True`, `border_min_x/max_x/min_y/max_y` (0..1, y from the BOTTOM).
- Fast Cycles: `max_bounces 8`, `transmission_bounces 8`, `diffuse_bounces 2`, `volume_bounces 0`, adaptive sampling threshold 0.03, denoise on. A `Volume Absorption` node in the water made it dark and slow.
- `view_transform='Standard'`, exposure 0 for a match; Godot applies ACES itself, so the grade is done afterwards.
- `Material.use_nodes` is deprecated (removed in 6.0) but still works in 5.2.

## ffmpeg / ogv (WinGet build under `AppData\Local\Microsoft\WinGet\Packages\yt-dlp.FFmpeg_*`)
- `-c:v libtheora -q:v 8 -pix_fmt yuv420p out.ogv` works; `-pattern_type glob` is NOT supported, use `name_%04d.png`.
- Contact sheet: `-framerate 1 -i seq_%02d.png -vf "scale=iw*0.6:ih*0.6,tile=3x3" -frames:v 1 sheet.png`.
- Per-channel gamma: `lutrgb=r='pow(val/maxval\,0.92)*maxval':g=...` (commas escaped with a backslash).
- Horizontal falloff by position: build a gradient image with `geq` and `blend=all_mode=multiply`.
- No PIL/numpy in the system Python (use Blender's Python or ffmpeg).
