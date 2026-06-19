extends Node3D
## 把 12 個 Meshy 西門素材排成 6x2 編號網格，打中性光、自動正規化大小，
## 截一張圖供使用者挑「要貼圖的關鍵物件」。
## 跑法：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureXimenLineup.tscn

const DIR := "res://assets/3d/environments/ximen/prototypes/"
const MODELS := [
	["1 店面 storefront", "ximen_storefront_facade_01"],
	["2 捷運 mrt", "ximen_mrt_exit_01"],
	["3 招牌叢 sign-cluster", "ximen_neon_sign_cluster_01"],
	["4 小吃攤 food-stall", "ximen_food_stall_01"],
	["5 便利店 conv", "ximen_convenience_entrance_01"],
	["6 路燈桿 pole", "ximen_utility_pole_light_01"],
	["7 雜物 clutter", "ximen_street_clutter_01"],
	["8 公寓牆 apartment*", "ximen_apartment_facade_01"],
	["9 轉角店屋 shophouse*", "ximen_corner_shophouse_01"],
	["10 直立招牌 neon-V*", "ximen_neon_vertical_01"],
	["11 橫向燈箱 neon-H*", "ximen_neon_horizontal_01"],
	["12 雜物2 clutter2*", "ximen_street_clutter_02"],
]
const COLS := 6
const SPACING_X := 3.4
const SPACING_Z := 4.6
const TARGET := 2.3   # 每個模型最長邊正規化到的尺寸

func _ready() -> void:
	_build_environment()
	for i in MODELS.size():
		var col := i % COLS
		var row := i / COLS
		var gx := (col - (COLS - 1) / 2.0) * SPACING_X
		var gz := row * SPACING_Z
		_place_model(MODELS[i][0], DIR + MODELS[i][1] + ".glb", Vector3(gx, 0.0, gz))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_ximen_lineup.png")
	print("LINEUP_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()

func _place_model(label: String, path: String, gridpos: Vector3) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		print("LOAD FAIL: ", path)
		return
	var inst := ps.instantiate() as Node3D
	add_child(inst)
	# 正規化大小
	var ab := _world_aabb(inst)
	var maxdim: float = max(ab.size.x, max(ab.size.y, ab.size.z))
	var s: float = TARGET / maxdim if maxdim > 0.0001 else 1.0
	inst.scale = Vector3(s, s, s)
	# 置中於 gridpos、底貼 y=0
	ab = _world_aabb(inst)
	var center := ab.get_center()
	inst.global_position += Vector3(gridpos.x - center.x, -ab.position.y, gridpos.z - center.z)
	# 底座圓盤（讓每個物件有清楚落點）
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.3; cyl.bottom_radius = 1.3; cyl.height = 0.05
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.16, 0.17, 0.22)
	disc.mesh.surface_set_material(0, dm)
	disc.position = Vector3(gridpos.x, 0.02, gridpos.z)
	add_child(disc)
	# 編號標籤（只標號碼，避免文字互疊；名稱對照寫在訊息裡）
	var tag := Label3D.new()
	tag.text = label.split(" ")[0]
	tag.font_size = 120
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 0.86, 0.35)
	tag.outline_size = 18
	tag.position = Vector3(gridpos.x, 3.0, gridpos.z)
	add_child(tag)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 30)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.13, 0.14, 0.18)
	ground.mesh.surface_set_material(0, gmat)
	ground.position = Vector3(0, 0, SPACING_Z * 0.5)
	add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 58
	cam.position = Vector3(0, 12.5, 13.5)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, SPACING_Z * 0.5), Vector3.UP)
	add_child(cam)
	cam.make_current()

func _world_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var has := false
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			var local: AABB = n.mesh.get_aabb()
			var gt: Transform3D = n.global_transform
			for i in 8:
				var corner := local.position + Vector3(
					local.size.x * float(i & 1),
					local.size.y * float((i >> 1) & 1),
					local.size.z * float((i >> 2) & 1))
				var wp := gt * corner
				if not has:
					result = AABB(wp, Vector3.ZERO); has = true
				else:
					result = result.expand(wp)
		for c in n.get_children():
			stack.append(c)
	return result
