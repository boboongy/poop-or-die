extends SceneTree
## Sets the game's main scene (the web build needs one; the editor runs used an explicit scene) and prints the web renderer.
## Godot writes project.godot itself (ProjectSettings.save): Claude does not hand-edit that file.
##   "<console exe>" --headless --path . --script tools/set_main_scene.gd


func _init() -> void:
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/level_toilet.tscn")
	print("web renderer: ", ProjectSettings.get_setting("rendering/renderer/rendering_method.web", "(no setting)"))
	print("save: ", error_string(ProjectSettings.save()))
	quit()
