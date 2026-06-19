extends Node3D
## 把貼圖好的西門素材組成一條街 + 氛圍後製，固定 3/4 俯角截圖看「在地」觀感。
## 跑法：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureXimenStreet.tscn

const DIR := "res://assets/3d/environments/ximen/prototypes/"

# [檔名, x, z, yaw度, 目標高/尺寸, 模式]  模式: "H"=依高度縮放(建築) / "S"=依最長邊縮放(道具/招牌)
const BUILDINGS := [
	["ximen_storefront_facade_01", -5.6, 5.0, 90, 3.2, "H"],
	["ximen_apartment_facade_01", -6.0, 11.0, 90, 4.8, "H"],
	["ximen_corner_shophouse_01", -6.2, 16.0, 90, 5.0, "H"],   # 糊的→擺最遠當背景
	["ximen_mrt_exit_01", 5.6, 5.0, -90, 3.8, "H"],
	["ximen_convenience_entrance_01", 6.0, 12.0, -90, 4.6, "H"],
]
const SIGNS := [
	["ximen_neon_sign_cluster_01", -4.4, 5.5, 90, 3.0, "S", 3.0],
	["ximen_neon_vertical_01", 4.3, 8.5, -90, 3.6, "S", 0.0],
	["ximen_neon_horizontal_01", -4.5, 12.0, 90, 2.6, "S", 3.0],
]
const DRESSING := [
	["ximen_food_stall_01", 2.0, 7.0, 205, 2.2, "S", 0.0],
	["ximen_utility_pole_light_01", -3.4, 11.0, 0, 3.2, "S", 0.0],
	["ximen_street_clutter_01", 3.2, 14.0, 30, 1.9, "S", 0.0],
	["ximen_street_clutter_02", -3.0, 3.0, -20, 1.9, "S", 0.0],
]
# 霓虹光池 [x,y,z, r,g,b, energy, range]
const NEONS := [
	[-3.0, 2.6, 3.5, 1.0, 0.15, 0.7, 5.0, 9.0],
	[3.0, 2.2, 6.5, 0.2, 0.9, 1.0, 5.0, 9.0],
	[1.4, 1.2, 5.0, 1.0, 0.6, 0.2, 3.5, 6.0],
	[-3.2, 2.4, 10.5, 1.0, 0.2, 0.8, 4.0, 8.0],
	[0.0, 0.4, 8.0, 0.2, 0.7, 1.0, 2.6, 10.0],
	[0.0, 5.0, 2.0, 0.4, 0.45, 0.9, 1.6, 15.0],
]

func _ready() -> void:
	_build_environment()
	for b in BUILDINGS:
		_place(b[0], Vector3(b[1], 0, b[2]), b[3], b[4], b[5], 0.0)
	for s in SIGNS:
		_place(s[0], Vector3(s[1], 0, s[2]), s[3], s[4], s[5], s[6])
	for d in DRESSING:
		_place(d[0], Vector3(d[1], 0, d[2]), d[3], d[4], d[5], d[6])
	for n in NEONS:
		var l := OmniLight3D.new()
		l.position = Vector3(n[0], n[1], n[2])
		l.light_color = Color(n[3], n[4], n[5])
		l.light_energy = n[6]
		l.omni_range = n[7]
		l.light_specular = 1.0
		add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_ximen_street.png")
	print("STREET_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()

func _place(name: String, pos: Vector3, yaw_deg: float, target: float, mode: String, y_offset: float) -> void:
	var ps := load(DIR + name + ".glb") as PackedScene
	if ps == null:
		print("LOAD FAIL: ", name); return
	var inst := ps.instantiate() as Node3D
	add_child(inst)
	inst.rotation_degrees = Vector3(0, yaw_deg, 0)
	var ab := _world_aabb(inst)
	var s := 1.0
	if mode == "H":
		s = target / ab.size.y if ab.size.y > 0.001 else 1.0
	else:
		var m: float = max(ab.size.x, max(ab.size.y, ab.size.z))
		s = target / m if m > 0.001 else 1.0
	inst.scale = Vector3(s, s, s)
	ab = _world_aabb(inst)
	var center := ab.get_center()
	inst.global_position += Vector3(pos.x - center.x, y_offset - ab.position.y, pos.z - center.z)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.2, 0.32)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC   # 避開 ACES 把霓虹去飽和
	env.tonemap_exposure = 1.05
	# 霧
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.18, 0.32)
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0
	# glow（霓虹 bloom）
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	we.environment = env
	# 移軸 DOF（箱庭微縮感）— Godot 4.5 掛在 camera_attributes
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 30.0
	attrs.dof_blur_far_transition = 8.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 9.0
	attrs.dof_blur_near_transition = 4.0
	attrs.dof_blur_amount = 0.1
	we.camera_attributes = attrs
	add_child(we)

	# 微弱主光（夜，靠霓虹主導）
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_energy = 0.35
	moon.light_color = Color(0.5, 0.6, 0.9)
	add_child(moon)

	# 濕柏油地面
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(34, 44)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.06, 0.085)
	gmat.metallic = 0.35
	gmat.roughness = 0.22
	ground.mesh.surface_set_material(0, gmat)
	ground.position = Vector3(0, 0, 9)
	add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 50
	cam.position = Vector3(0, 13.0, -10.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 10.0), Vector3.UP)
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
