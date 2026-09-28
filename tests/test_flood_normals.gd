extends SceneTree
## Owner-visible bug 2026-09-28: the Level 3 flood water was BLACK in the web build (Chrome). Its two ripple normal maps were
## NoiseTexture2Ds, which are generated on a worker thread; the web build has no threads. The water's normal maps must be ready
## on the frame they are made, with no thread and no waiting: an image with mipmaps, pointing mostly up (blue > 0.5), never black.
const FloodWater := preload("res://scripts/flood_water.gd")
const T := preload("res://tests/t.gd")


func _init() -> void:
	for args in [[0.018, 1], [0.045, 2]]:
		var tex: Texture2D = FloodWater._normal_tex(args[0], args[1])
		var img := tex.get_image() if tex != null else null
		T.check(img != null and not img.is_empty(), "normal map %s: has an image the same frame it is made" % [args])
		if img == null or img.is_empty():
			continue
		T.check(img.has_mipmaps(), "normal map %s: has mipmaps (the shader samples it with a mipmap filter)" % [args])
		var black := 0
		var up := 0
		var n := 0
		for y in range(0, img.get_height(), 16):
			for x in range(0, img.get_width(), 16):
				var c := img.get_pixel(x, y)
				n += 1
				if c.r + c.g + c.b < 0.05:
					black += 1
				if c.b > 0.5:
					up += 1
		print("normal map %s: %d samples, %d black, %d pointing up" % [args, n, black, up])
		T.check(black == 0, "normal map %s: no black pixels (%d of %d)" % [args, black, n])
		T.check(up == n, "normal map %s: every sample points up (%d of %d)" % [args, up, n])
	T.finish(self)
