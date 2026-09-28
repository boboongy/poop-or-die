# Toilet environment: Godot notes

**File:** `exports/toilet-environment.glb` (1.6 MB). Units: metres, Y-up on import. Level size 18.1 x 3.0 x 8.4 m.

## How it was made
The .blend is authored in centimetres (scene unit scale 0.01). The glTF exporter ignores unit scale, so `scripts/50_env_export_gltf.py` parents everything under a root scaled 0.01 (`EXPORT_SCALE` in
`scripts/lib/env_config.py`). Re-export: `blender -b toilet-environment.blend --python scripts/50_env_export_gltf.py`, then `--python scripts/51_env_validate.py` (must end `0 FAIL`). The script does not save the .blend.

## Contents
* 231 visual meshes (`SM_*`), 59 mesh blocks (linked duplicates share a block), 32,500 tris as instanced, 3,270 unique.
* 11 materials, 30 embedded 512 px textures. No cameras, no lights.
* 130 collision proxies, named `<instance name>-convcolonly` (Godot removes the mesh and makes a StaticBody3D with a convex shape; see 'Collision per instance' below).

## To do in Godot
1. Import the .glb and check that the size is right (about 18 m long) and that collision shapes appear (`-convcolonly` is VERIFIED with Godot 4.7.2's editor import, 2026-09-22).
2. Lights are not exported: recreate the sickly green fluorescent ceiling-grid look from SPEC "Light plan" with Godot lights / WorldEnvironment.
3. `SM_Picture_Stall_*` (10 objects) carry a non-unit object scale in the .blend (validator WARN); harmless, they exported at the right size.

## Not in the export
`Review` collection (lookdev camera) and helper objects (`PROBE*`, `CAM_*`, `LGT_*`) are ignored on purpose.

## Ledge fix (2026-09-22, re-import once)
`SM_SinkLedge_01` (the tiled block at the far east end) was standing inside the last basin (`SM_Sink_10`). It is moved to x >= 10.305 m in Godot (west face 2.5 cm east of the basin edge at 10.28 m; far edge 10.935 m, inside the room whose east wall is at 12.65 m), same z range, and it now has a collision proxy `SM_SinkLedge-convcolonly` (convex hull of the ledge; 26 proxies in the file, was 25). The validator is unchanged (22 PASS / 1 WARN / 0 FAIL). Game side: `bash tests/run.sh toilet_geometry` should now fail with 'known defect fixed by the factory' (then empty KNOWN); re-run `--slow` and `test_walkers` (a new collision body next to the sink-10 stand spot x 10.05, z 0.38 changes the navmesh there).

## Flush handle (2026-09-22, re-import once): `SM_FlushHandle_R<row>_<nn>`, 20 nodes (FACTORY_TODO items 4 and 5d)
A **side lever** as its own object on each toilet (chrome, placeholder shape, look approved by the owner: lever at the front-left of the tank), one node per toilet with the same name suffix as the toilet (`SM_FlushHandle_R1_01` belongs to `SM_Toilet_R1_01_Body`). All 20 share ONE mesh.
* **The node origin is the lever's PIVOT** (the centre of the round boss on the tank face). Godot position, toilet `R1_01`: (1.36, 0.72, -2.39) m; relative to the toilet body origin: 14 cm to the toilet's left (toilet-local x -14 cm), 27 cm behind the toilet origin (the tank face), 72 cm above the floor. Row 2 toilets are rotated 180 degrees and so are their handles: the placement is the same relative to each toilet.
* The arm points along the node's local +X, 10 cm long with a grip knob (free end at about 11.2 cm), resting 8 degrees below horizontal. The boss stands 1.5 cm proud of the tank face.
* **Press = rotate the node about its local Z axis by 30 degrees so that the free end goes DOWN.** Measured in real Godot (`tools/godot_check/handle_axis_check.gd`): **row 1 (`SM_FlushHandle_R1_*`): rotation about local +Z by -30 degrees (`rotation.z = -0.5236`); row 2 (`R2_*`, turned 180 degrees): +30 degrees (`rotation.z = +0.5236`).** The free end drops 5.5 cm. Spring back to 0 on release. Do not derive the sign on paper: the two rows differ.
* Trigger volume suggestion: a 12 cm sphere at the pivot. The handle has no collision proxy (it stands 1.5 cm off the tank). The character clip that presses it is `press_flush` (Bob), still to do: it will be authored against this exact position.
* **The old placeholder stub is gone:** the shared toilet mesh had a loose 4 cm rod on the tank's +X side (22 vertices); it was removed, so all 20 toilet bodies changed (394 -> 372 vertices, 338 -> 308 polygons). Nothing else on the toilet moved.
* Validator: 22 PASS / 1 WARN (old, non-unit scale) / 0 FAIL. .glb 1.64 MB, 278 nodes (was 258), 251 visual meshes, 26 collision proxies.

## Collision per instance (2026-09-22, re-import once; FACTORY_TODO items 1 and 7)
* **Every** stall door (20), front panel (20), partition (18), pilaster (22), toilet (20) and sink (10), plus the ledge, now has its OWN collision proxy: 130 in the file with the 19 shell boxes (was 26: one per kind, on the first copy only). Names: `<instance name>-convcolonly`, for example `SM_StallDoor_R2_01-convcolonly`, `SM_Toilet_R2_01_Body-convcolonly`, `SM_Sink_10-convcolonly`. **The six old one-per-kind names are gone** (`SM_StallDoor-convcolonly`, `SM_StallFrontPanel-convcolonly`, `SM_StallPartition-convcolonly`, `SM_StallPilaster-convcolonly`, `SM_Toilet_Body-convcolonly`, `SM_Sink-convcolonly`) and `SM_SinkLedge-convcolonly` is now `SM_SinkLedge_01-convcolonly`: search the game code for them.
* **Each proxy is a child of its own visual node**, so after Godot's import the collision body is a `StaticBody3D` child of the visual mesh node (same name as the mesh node). A **stall door's body therefore swings with the door**: rotate the door node about Y (its origin is the hinge, the left edge) and its collision follows (measured in real Godot: a 90 degree swing moves the door body's centre by 0.460 m).
* The proxies equal their visuals to 0.00 cm (boxes for the stall parts, convex hulls for toilets, sinks and the ledge). The sink proxy stops at the basin rim: the faucet (4 cm) has no collision on purpose.
* Verified with Godot 4.7.2's real editor import (`tools/godot_check/import_collision_check.sh`): 130 `StaticBody3D`, 130 `ConvexPolygonShape3D`, all directly under their visual mesh node.
* **Game side, when you re-import:** the interim box collision built by `stalls.gd` (and the door bodies it adds) can be removed once these are verified; re-run `test_walkers` and the slow all-stalls test, because every stall now blocks. NOT covered (not in the TODO): trash bins, mirrors, soap dispensers, pictures, pipes, flush handles: they have no collision.
* The file now has 382 nodes; the validator budget is 400, so further nodes need merging or removing something first.
