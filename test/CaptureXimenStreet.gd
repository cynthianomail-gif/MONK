extends Node3D
## 把貼圖好的西門素材「模組化重複」鋪成一條長街 + 氛圍後製，固定 3/4 俯角截圖。
## 模組件本就是給重用的：沿街谷兩側交替鋪建築、隨機換模型/微調大小角度，遠端靠霧+DOF 收掉重複感。
## 跑法：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureXimenStreet.tscn

const DIR := "res://assets/3d/environments/ximen/prototypes/"
const BUILDINGS := [
	"ximen_storefront_facade_01", "ximen_corner_shophouse_01", "ximen_mrt_exit_01",
	"ximen_neon_tower_01", "ximen_ktv_building_01", "ximen_bubbletea_shop_01",
	"ximen_ramen_shop_01", "ximen_parking_garage_01", "ximen_drugstore_01",
]
const WALL_SIGNS := ["ximen_neon_sign_cluster_01"]
const POLE_SIGN := "ximen_neon_vertical_01"
const CLUTTER := ["ximen_street_clutter_01", "ximen_street_clutter_02"]

const STREET_START := 2.0
const STREET_END := 46.0
const SIDE_X := 5.4

var _rng := RandomNumberGenerator.new()
var _neon_cols := [Color(1.0, 0.18, 0.7), Color(0.2, 0.85, 1.0), Color(1.0, 0.6, 0.2), Color(0.7, 0.3, 1.0)]

func _ready() -> void:
	_rng.seed = 20260619
	_build_environment()
	_build_street()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_ximen_street.png")
	print("STREET_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()

func _build_street() -> void:
	# 兩側交替鋪建築
	var z := STREET_START
	var side := -1.0
	var bidx := 0
	while z < STREET_END:
		var model: String = BUILDINGS[bidx % BUILDINGS.size()]
		bidx += _rng.randi_range(1, 2)   # 跳著選，避免規律
		var x := side * (SIDE_X + _rng.randf_range(-0.4, 0.7))
		var yaw := (90.0 if side < 0.0 else -90.0) + _rng.randf_range(-4.0, 4.0)
		var h := _rng.randf_range(3.6, 5.6)
		_place(model, Vector3(x, 0, z), yaw, h, "H", 0.0)
		side = -side
		z += _rng.randf_range(3.2, 4.4)

	# 牆面招牌（高掛）+ 每個配一盞霓虹光
	var sz := STREET_START + 4.0
	var sside := 1.0
	while sz < STREET_END - 4.0:
		var sign: String = WALL_SIGNS[_rng.randi() % WALL_SIGNS.size()]
		var sx := sside * (SIDE_X - 1.6)
		_place(sign, Vector3(sx, 0, sz), (90.0 if sside < 0.0 else -90.0), _rng.randf_range(2.4, 3.2), "S", _rng.randf_range(2.6, 3.6))
		_neon(Vector3(sx, _rng.randf_range(2.6, 3.4), sz), _neon_cols[_rng.randi() % _neon_cols.size()], 4.5, 9.0)
		sside = -sside
		sz += _rng.randf_range(5.5, 7.5)

	# 直立招牌站街緣
	for zz in [7.0, 19.0, 31.0]:
		var ps := -1.0 if _rng.randf() < 0.5 else 1.0
		var px := ps * (SIDE_X - 2.6)
		_place(POLE_SIGN, Vector3(px, 0, zz + _rng.randf_range(-1, 1)), (90.0 if ps < 0 else -90.0), 3.6, "S", 0.0)
		_neon(Vector3(px, 2.2, zz), _neon_cols[_rng.randi() % _neon_cols.size()], 4.0, 8.0)

	# 小吃攤（近處 hero prop）+ 暖光
	_place("ximen_food_stall_01", Vector3(2.0, 0, 6.0), 205.0, 2.3, "S", 0.0)
	_neon(Vector3(2.0, 1.2, 6.0), Color(1.0, 0.55, 0.2), 3.5, 6.0)

	# 路燈桿 + 雜物 散沿街
	for zz in [10.0, 22.0, 34.0]:
		_place("ximen_utility_pole_light_01", Vector3((-1.0 if int(zz) % 2 == 0 else 1.0) * (SIDE_X - 2.2), 0, zz), 0.0, 3.4, "S", 0.0)
	var cz := 4.0
	while cz < STREET_END - 6.0:
		_place(CLUTTER[_rng.randi() % CLUTTER.size()], Vector3((-1.0 if _rng.randf() < 0.5 else 1.0) * _rng.randf_range(2.0, 3.2), 0, cz), _rng.randf_range(0, 360), 1.9, "S", 0.0)
		cz += _rng.randf_range(7.0, 10.0)

	# 街心地面霓虹光池（往深處鋪，給縱深）
	var lz := 5.0
	while lz < STREET_END:
		_neon(Vector3(_rng.randf_range(-1.5, 1.5), 0.4, lz), _neon_cols[_rng.randi() % _neon_cols.size()], 2.4, 9.0)
		lz += _rng.randf_range(5.0, 7.0)

func _neon(pos: Vector3, col: Color, energy: float, rng_range: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_range
	l.light_specular = 1.0
	add_child(l)

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
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.17, 0.32)
	env.fog_density = 0.035
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	we.environment = env
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 40.0
	attrs.dof_blur_far_transition = 14.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 9.0
	attrs.dof_blur_near_transition = 4.0
	attrs.dof_blur_amount = 0.1
	we.camera_attributes = attrs
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_energy = 0.35
	moon.light_color = Color(0.5, 0.6, 0.9)
	add_child(moon)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 70)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.06, 0.085)
	gmat.metallic = 0.35
	gmat.roughness = 0.22
	ground.mesh.surface_set_material(0, gmat)
	ground.position = Vector3(0, 0, 22)
	add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 55
	cam.position = Vector3(0, 14.5, -12.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 24.0), Vector3.UP)
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
