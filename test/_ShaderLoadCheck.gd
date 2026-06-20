extends SceneTree
## headless shader 載入檢查：godot --headless --script res://test/_ShaderLoadCheck.gd
func _init() -> void:
	var paths := [
		"res://assets/shaders/okami/ink_toon.gdshader",
		"res://assets/shaders/okami/ink_ground.gdshader",
		"res://assets/shaders/okami/ink_outline.gdshader",
		"res://assets/shaders/okami/ink_paper.gdshader",
	]
	for p in paths:
		assert(ResourceLoader.exists(p), "MISSING: " + p)
		var sh := load(p) as Shader
		assert(sh != null, "NOT A SHADER: " + p)
	print("SHADERS_OK ", paths.size())
	quit()
