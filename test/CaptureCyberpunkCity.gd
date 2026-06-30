extends Node
## 把下載的 Cyberpunk City（golukumar, CC-BY）丟進引擎試看：自動量合併 AABB，
## 拍「3/4 俯角總覽」＋「街面眼高視角」各一張，套上夜景霓虹後製（glow/fog/filmic）模擬遊戲內觀感。
## 跑法：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureCyberpunkCity.tscn

const GLB := "res://assets/3d/environments/cyberpunk_city/cyberpunk_city.glb"

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame

	# 夜景霓虹環境（讓自發光招牌發亮、霧給縱深）
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.36)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.15, 0.30)
	env.fog_density = 0.010
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50, -30, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.55, 0.62, 0.9)
	root.add_child(fill)

	# 場景本體
	var scn := load(GLB) as PackedScene
	if scn == null:
		push_error("LOAD FAIL: " + GLB)
		get_tree().quit(); return
	var city := scn.instantiate() as Node3D
	root.add_child(city)
	await get_tree().process_frame

	var meshes := _all_mesh_instances(city)
	var aabb := _combined_aabb(city)
	print("CITY_MESH_COUNT ", meshes.size())
	print("CITY_AABB pos=", aabb.position, " size=", aabb.size)
	if meshes.is_empty():
		push_error("NO MESHES IN GLB")
		get_tree().quit(); return
	var center := aabb.get_center()
	var floor_y: float = aabb.position.y
	var along_x: bool = aabb.size.x >= aabb.size.z   # 長水平軸＝街的走向
	var long_len: float = aabb.size.x if along_x else aabb.size.z
	var maxdim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 60.0
	cam.near = 0.05
	cam.far = maxdim * 6.0 + 300.0
	root.add_child(cam)

	# Shot A：3/4 俯角總覽（看清整體規模）
	var d: float = maxdim * 0.9 + 5.0
	cam.position = center + Vector3(d * 0.6, maxdim * 0.5 + 3.0, d * 0.6)
	cam.look_at(center, Vector3.UP)
	await _settle()
	_save("res://_cyberpunk_city_overview.png")

	# Shot B：街面眼高視角（站街頭、沿街看向另一端，＝走進去的 POV）
	var eye: float = floor_y + 1.7
	var half: float = long_len * 0.5
	if along_x:
		cam.position = Vector3(center.x - half + 2.0, eye, center.z)
		cam.look_at(Vector3(center.x + half, eye, center.z), Vector3.UP)
	else:
		cam.position = Vector3(center.x, eye, center.z - half + 2.0)
		cam.look_at(Vector3(center.x, eye, center.z + half), Vector3.UP)
	await _settle()
	_save("res://_cyberpunk_city_street.png")

	get_tree().quit()

func _settle() -> void:
	for i in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _save(path: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path, " ", img.get_width(), "x", img.get_height())

func _combined_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _all_mesh_instances(node):
		var mi := c as MeshInstance3D
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a; first = false
		else:
			out = out.merge(a)
	return out

func _all_mesh_instances(node: Node) -> Array:
	var arr: Array = []
	if node is MeshInstance3D:
		arr.append(node)
	for ch in node.get_children():
		arr.append_array(_all_mesh_instances(ch))
	return arr
