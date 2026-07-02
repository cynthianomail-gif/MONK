extends SceneTree
## headless shader 載入檢查：godot --headless --script res://test/_ShaderLoadCheck.gd
func _init() -> void:
	var paths := [
		"res://assets/shaders/stylized/plaster.gdshader",
		"res://assets/shaders/stylized/cobblestone.gdshader",
		"res://assets/shaders/stylized/roof_tiles.gdshader",
		"res://assets/shaders/stylized/corrugated_metal.gdshader",
	]
	for p in paths:
		assert(ResourceLoader.exists(p), "MISSING: " + p)
		var sh := load(p) as Shader
		assert(sh != null, "NOT A SHADER: " + p)
	print("SHADERS_OK ", paths.size())
	quit()
