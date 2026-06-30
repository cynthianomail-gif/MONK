extends Node
## 量 cyberpunk_city.glb 的效能成本：總三角面數、貼圖張數與解析度、估算貼圖記憶體。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/DiagCyberpunk.tscn

const GLB := "res://assets/3d/environments/cyberpunk_city/cyberpunk_city.glb"

func _ready() -> void:
	var inst := (load(GLB) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	var tris := 0
	var surfaces := 0
	var seen := {}          # texture path -> [w, h]
	for n in _all(inst):
		if n is MeshInstance3D and n.mesh:
			var mesh: Mesh = n.mesh
			for s in mesh.get_surface_count():
				surfaces += 1
				var idx := mesh.surface_get_array_index_len(s)
				var vtx := mesh.surface_get_array_len(s)
				tris += int((idx if idx > 0 else vtx) / 3)
				var mat = mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					for tex in [
						mat.albedo_texture, mat.normal_texture, mat.emission_texture,
						mat.roughness_texture, mat.metallic_texture, mat.ao_texture,
					]:
						if tex != null:
							var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
							if not seen.has(key):
								seen[key] = [tex.get_width(), tex.get_height()]

	var tex_bytes := 0
	var buckets := {}
	for k in seen:
		var wh = seen[k]
		tex_bytes += wh[0] * wh[1] * 4
		var label := "%dx%d" % [wh[0], wh[1]]
		buckets[label] = buckets.get(label, 0) + 1

	print("DIAG_TRIS ", tris)
	print("DIAG_SURFACES ", surfaces)
	print("DIAG_TEX_COUNT ", seen.size())
	print("DIAG_TEX_BUCKETS ", buckets)
	print("DIAG_TEX_MEM_MB ", int(tex_bytes / 1048576.0))
	get_tree().quit(0)

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
