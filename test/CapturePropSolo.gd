extends Node
## 單體道具驗證：只放販賣機 GLB＋中性地面＋光，3/4 角度近拍，並印出合併 AABB 尺寸。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CapturePropSolo.tscn

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame

	# 環境光（平亮，看得清模型）
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.85, 0.9)   # 亮背景＝暗模型也能剪影
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.85)
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 35, 0)
	key.light_energy = 1.1
	root.add_child(key)

	# 地面
	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	gp.mesh = pm
	root.add_child(gp)

	# 道具（命令列 `-- <res 路徑>` 指定，預設販賣機）
	var prop_path := "res://assets/3d/props/vending_machine_01.glb"
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() > 0:
		prop_path = uargs[0]
	var scn := load(prop_path) as PackedScene
	var vm := scn.instantiate() as Node3D
	root.add_child(vm)
	await get_tree().process_frame

	# 量合併 AABB（世界座標）＋印出每個 mesh 的材質資訊
	var meshes := _all_mesh_instances(vm)
	print("PROP_MESH_COUNT ", meshes.size())
	for m in meshes:
		var mi := m as MeshInstance3D
		var surf := 0
		if mi.mesh: surf = mi.mesh.get_surface_count()
		var mat0 := mi.mesh.surface_get_material(0) if (mi.mesh and surf > 0) else null
		print("  MESH ", mi.name, " surfaces=", surf, " mat=", mat0)
	var aabb := _combined_aabb(vm)
	print("PROP_AABB pos=", aabb.position, " size=", aabb.size)
	var center := aabb.position + aabb.size * 0.5

	# 修 Meshy 匯入材質：強制不透明（base color 帶 alpha 會被判透明 → 整台消失）
	for m in meshes:
		var mi2 := m as MeshInstance3D
		if mi2.mesh == null: continue
		for s in mi2.mesh.get_surface_count():
			var mat = mi2.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				bm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				var c := bm.albedo_color
				c.a = 1.0
				bm.albedo_color = c
				print("  FIXED ", mi2.name, " surf", s, " was_transp_now_opaque")

	# 相機：正面近拍（front 約在 +Z 或 -Z，先打 +Z 面）
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.current = true
	var reach: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var dist: float = reach * 1.6 + 0.6
	cam.position = center + Vector3(dist * 0.55, reach * 0.25, dist * 0.85)   # 3/4 前方
	cam.look_at(center, Vector3.UP)
	root.add_child(cam)

	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var base := prop_path.get_file().get_basename()
	img.save_png("res://_prop_%s_solo.png" % base)
	print("PROP_SOLO_DONE ", base, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()

func _combined_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _all_mesh_instances(node):
		var mi := c as MeshInstance3D
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
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
