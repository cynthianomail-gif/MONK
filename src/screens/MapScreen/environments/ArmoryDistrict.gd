extends Node3D
## 程式化「軍火庫區」環境（黑道軍火倉庫街，幾何盒體＋水墨 shader）。
## 與 ShrineStreet 同架構、同 4 個水墨 shader，但換暗鋼鐵調＋軍火庫內容：
## 鐵皮倉庫、武器箱/油桶/武器架、紅燈籠、街尾熔鑄爐建築(地標＝Boss 巢)、煙硝暗霧。
## 概念錨點：_art_review/_armory_district_okami_test.png。

const TOON_SHADER := preload("res://assets/shaders/okami/ink_toon.gdshader")
const GROUND_SHADER := preload("res://assets/shaders/okami/ink_ground.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/okami/ink_outline.gdshader")
const PAPER_SHADER := preload("res://assets/shaders/okami/ink_paper.gdshader")
const CORRUGATED_SHADER := preload("res://assets/shaders/okami/ink_corrugated.gdshader")

func _ready() -> void:
	_build_env(self)
	_build_district(self)
	_build_forge(self)
	_build_lanterns(self)
	_build_props(self)
	_build_backdrop(self)
	_build_paper_overlay()
	_attach_outline_deferred()
	print("ARMORY_DISTRICT ready")

# ── 描邊：延幀掛到當前相機 ──
func _attach_outline_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_attach_outline_to_camera()
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_apply_ink(player)
		print("ARMORY_INK_PLAYER ok")

func _attach_outline_to_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	mi.extra_cull_margin = 16384.0
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.render_priority = 100
	mi.material_override = mat
	cam.add_child(mi)
	mi.position = Vector3(0, 0, -0.5)

func _apply_ink(node: Node) -> void:
	for c in node.get_children():
		_apply_ink(c)
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _toon_mat(Color(0.28, 0.25, 0.24))

# ── 材質 helper ─────────────────────────────────────────
func _toon_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("albedo", Color(0.26, 0.25, 0.26))   # 濕暗柏油，非淺石
	return m

func _corrugated_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CORRUGATED_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _steel_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _corrugated_mat(color)   # 浪板鐵皮一條條
	root.add_child(mi)

func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _toon_mat(color)
	root.add_child(mi)
	return mi

func _emissive(root: Node3D, pos: Vector3, size: Vector3, col: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	mi.material_override = m
	root.add_child(mi)

func _drum(root: Node3D, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 1.05
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _toon_mat(color)
	root.add_child(mi)

func _omni(root: Node3D, pos: Vector3, col: Color, energy: float, rng_: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	root.add_child(l)

# ── ③ 和紙顆粒 overlay ──────────────────────────────────
func _build_paper_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	rect.material = mat
	layer.add_child(rect)

# ── 環境：夜、暗鋼鐵、煙硝、爐火暖光透出 ──────────────────
func _build_env(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.12, 0.14)            # 暗煙夜空
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.33, 0.38)
	env.ambient_light_energy = 0.68                            # 暗壓迫但側邊倉庫看得到
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.18                             # 爐火/燈籠暈但不過爆
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.18, 0.17)            # 暖煙硝
	env.fog_density = 0.011
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -38, 0)
	moon.light_color = Color(0.62, 0.64, 0.74)               # 冷弱月光
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	root.add_child(moon)

# ── 街區：兩排鐵皮倉庫＋武器箱/油桶/武器架/紅燈籠 ──────────
func _build_district(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(40, 0.2, 70)
	ground.mesh = gb
	ground.position = Vector3(0, -0.1, -12)
	ground.material_override = _ground_mat()
	root.add_child(ground)
	var floor_body := StaticBody3D.new()
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 70)
	cshape.shape = box
	floor_body.add_child(cshape)
	floor_body.position = Vector3(0, -0.1, -12)
	root.add_child(floor_body)

	var steels := [Color(0.25, 0.24, 0.26), Color(0.22, 0.22, 0.24), Color(0.27, 0.26, 0.27)]
	var wood := Color(0.36, 0.28, 0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var z := 2.0
	var i := 0
	while z > -32.0:
		var hgt := rng.randf_range(4.0, 6.5)   # 鐵皮倉庫稍高
		var w := rng.randf_range(5.0, 7.0)
		var d := rng.randf_range(5.0, 7.0)
		for side in [-1, 1]:
			var x := float(side) * rng.randf_range(7.5, 9.0)
			_steel_box(root, Vector3(x, hgt * 0.5, z), Vector3(w, hgt, d), steels[i % steels.size()])
			# 低矮單斜鐵皮頂(略高一側)
			_box(root, Vector3(x, hgt + 0.25, z), Vector3(w + 0.6, 0.5, d + 0.6), Color(0.14, 0.13, 0.15))
			var fx := x - float(side) * (w * 0.5 + 0.05)
			# 捲門洞口＋裡頭微弱暖光
			_box(root, Vector3(fx, 1.4, z), Vector3(0.12, 2.6, d * 0.5), Color(0.08, 0.08, 0.09))
			_emissive(root, Vector3(fx - float(side) * 0.05, 1.2, z), Vector3(0.06, 1.8, d * 0.42), Color(0.85, 0.42, 0.20), 1.1)
			# 門口紅燈籠
			_emissive(root, Vector3(fx - float(side) * 0.3, 2.6, z - d * 0.3), Vector3(0.4, 0.55, 0.4), Color(0.85, 0.20, 0.12), 1.7)
			_omni(root, Vector3(fx - float(side) * 0.3, 2.6, z - d * 0.3), Color(0.95, 0.34, 0.20), 1.7, 8.0)
			# 門口堆武器箱(疊兩個)＋油桶
			_box(root, Vector3(fx - float(side) * 0.7, 0.45, z + d * 0.2), Vector3(0.9, 0.9, 0.9), wood)
			_box(root, Vector3(fx - float(side) * 0.7, 1.15, z + d * 0.2), Vector3(0.7, 0.5, 0.7), wood)
			_drum(root, Vector3(fx - float(side) * 0.7, 0.5, z - d * 0.25), Color(0.20, 0.19, 0.20))
			# 武器架(幾根斜靠的細長桿)
			for r in range(3):
				_box(root, Vector3(fx - float(side) * 1.1, 1.0, z - d * 0.1 + float(r) * 0.18), Vector3(0.06, 2.0, 0.06), Color(0.13, 0.12, 0.13))
			i += 1
		z -= rng.randf_range(7.5, 9.5)

# ── 街尾熔鑄爐建築(地標＝Boss 巢，取代鳥居) ────────────────
func _build_forge(root: Node3D) -> void:
	var zf := -22.0
	# 主建築量體(暗鋼鐵浪板)
	_steel_box(root, Vector3(0, 5.5, zf), Vector3(12.0, 11.0, 7.0), Color(0.18, 0.17, 0.19))
	# 煙囪
	_box(root, Vector3(3.5, 12.5, zf), Vector3(1.2, 6.0, 1.2), Color(0.12, 0.11, 0.13))
	# 正面爐口(發光)＋拱
	_box(root, Vector3(0, 3.0, zf + 3.6), Vector3(5.0, 6.0, 0.6), Color(0.10, 0.10, 0.11))
	_emissive(root, Vector3(0, 2.6, zf + 3.9), Vector3(3.2, 3.6, 0.4), Color(1.0, 0.45, 0.14), 2.2)
	_emissive(root, Vector3(0, 0.7, zf + 4.2), Vector3(4.4, 0.5, 0.5), Color(1.0, 0.40, 0.12), 1.7)   # 爐口下熔光潑地
	# 爐火暖光打亮整條街尾
	_omni(root, Vector3(0, 3.0, zf + 4.5), Color(1.0, 0.46, 0.18), 3.4, 24.0)
	_omni(root, Vector3(0, 1.0, zf + 6.0), Color(1.0, 0.40, 0.16), 2.0, 14.0)
	# 飛濺火星(幾顆小發光塊)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for s in range(14):
		var sx := rng.randf_range(-2.2, 2.2)
		var sy := rng.randf_range(4.0, 9.0)
		_emissive(root, Vector3(sx, sy, zf + 3.8), Vector3(0.09, 0.09, 0.09), Color(1.0, 0.7, 0.3), 3.0)

# ── 紅燈籠列(沿街，暗街的暖點) ────────────────────────────
func _build_lanterns(root: Node3D) -> void:
	var z := 0.0
	while z > -28.0:
		for side in [-1, 1]:
			var x := float(side) * 5.6
			_box(root, Vector3(x, 2.2, z), Vector3(0.2, 4.4, 0.2), Color(0.11, 0.10, 0.12))   # 桿
			_emissive(root, Vector3(x, 4.2, z), Vector3(0.42, 0.6, 0.42), Color(0.88, 0.22, 0.13), 1.9)
			_omni(root, Vector3(x, 4.2, z), Color(0.95, 0.34, 0.20), 1.9, 9.0)
		z -= 6.0

# ── 路邊道具：油桶堆、武器箱、垂吊鐵鏈 ────────────────────
func _build_props(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	var wood := Color(0.34, 0.27, 0.17)
	var z := -3.0
	var k := 0
	while z > -26.0:
		var side := -1 if k % 2 == 0 else 1
		var bx := float(side) * 3.6
		# 油桶兩三個
		_drum(root, Vector3(bx, 0.5, z), Color(0.21, 0.19, 0.20))
		_drum(root, Vector3(bx + float(side) * 0.9, 0.5, z + 0.5), Color(0.18, 0.17, 0.18))
		_drum(root, Vector3(bx + float(side) * 0.45, 1.55, z + 0.25), Color(0.22, 0.20, 0.21))   # 疊一個
		# 武器木箱
		_box(root, Vector3(bx + float(side) * 0.2, 0.4, z - 0.9), Vector3(1.0, 0.8, 1.0), wood)
		# 垂吊鐵鏈(細長從上垂下)
		if k % 2 == 0:
			_box(root, Vector3(float(side) * 6.5, 4.5, z - 1.0), Vector3(0.08, 3.0, 0.08), Color(0.10, 0.10, 0.11))
		k += 1
		z -= rng.randf_range(5.0, 6.5)

# ── 遠景：暗工業剪影＋煙囪＋煙(取代杉林) ──────────────────
func _build_backdrop(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var x := -18.0
	while x < 18.0:
		var h := rng.randf_range(8.0, 18.0)
		_box(root, Vector3(x, h * 0.5 - 1.0, rng.randf_range(-46.0, -40.0)), Vector3(rng.randf_range(3.0, 6.0), h, 3.0), Color(0.18, 0.18, 0.20))
		# 偶爾一根煙囪
		if rng.randf() < 0.4:
			_box(root, Vector3(x + 1.0, h + 2.0, -44.0), Vector3(0.8, 5.0, 0.8), Color(0.15, 0.15, 0.17))
		x += rng.randf_range(3.0, 5.0)
