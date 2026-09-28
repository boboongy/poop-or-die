extends SceneTree
## Owner report 2026-09-21: "the table at the far end is colliding with the last far-end sink." Cause: the published toilet model has
## `SM_SinkLedge_01` (x 10.03..10.66, 0.88 m tall) standing INTO sink 10 (x 9.82..10.28). That is a model defect: it is fixed in the
## factory and republished (never edited here; see FACTORY_TODO.md). This test checks EVERY pair of sinks, ledges and bins for solid
## overlap. The one known defect is listed in KNOWN; anything else overlapping fails the test, and when the factory fixes the ledge the
## test fails on purpose with "known defect fixed" so the entry is removed and this guard becomes strict.
const T := preload("res://tests/t.gd")

const KNOWN: Array[String] = [] # empty 2026-09-23: factory fixed the ledge (FACTORY_TODO #12), no known defects left
const MIN_OVERLAP := 0.004 ## m^3 of intersection that counts as "standing in each other" (touching faces do not count)
const PREFIXES := ["SM_Sink_", "SM_SinkLedge_", "SM_TrashBin_"]


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.4)
	var meshes: Array[MeshInstance3D] = []
	for mi in lvl.get_node("NavRegion/Toilet").find_children("SM_*", "MeshInstance3D", true, false):
		for pre: String in PREFIXES:
			if String(mi.name).begins_with(pre):
				meshes.append(mi)
	var sinks := 0
	for mi in meshes:
		if String(mi.name).begins_with("SM_Sink_"):
			sinks += 1
	T.check(sinks == 10, "all 10 sinks found (%d), %d props checked in all" % [sinks, meshes.size()])
	var found: Array[String] = []
	for a in meshes.size():
		for b in range(a + 1, meshes.size()):
			var box_a: AABB = meshes[a].global_transform * meshes[a].get_aabb()
			var box_b: AABB = meshes[b].global_transform * meshes[b].get_aabb()
			var inter := box_a.intersection(box_b)
			if inter.has_volume() and inter.get_volume() >= MIN_OVERLAP:
				var names := [String(meshes[a].name), String(meshes[b].name)]
				names.sort()
				found.append("|".join(names))
				print("INFO  overlap %s: %.3f m^3 (x %.2f..%.2f)" % [names, inter.get_volume(), inter.position.x, inter.end.x])
	var unexpected: Array[String] = []
	for f in found:
		if not KNOWN.has(f):
			unexpected.append(f)
	T.check(unexpected.is_empty(), "no NEW props standing in each other (%s)" % str(unexpected))
	var fixed: Array[String] = []
	for k in KNOWN:
		if not found.has(k):
			fixed.append(k)
	T.check(fixed.is_empty(), "known defect fixed by the factory? remove from KNOWN: %s" % str(fixed))
	print("INFO  known model defects still present: %s" % str(found.filter(func(f: String) -> bool: return KNOWN.has(f))))
	T.finish(self)
