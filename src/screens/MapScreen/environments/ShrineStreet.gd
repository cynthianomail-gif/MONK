extends Node3D
## 程式化「水墨神社街」環境（幾何盒體＋水墨 shader，不貼 AI 圖）。
## 在 _ready 動態建：env/光、石板地面（含碰撞）、兩排店家（屋頂/三件套/木格/掛看板）、
## 石燈籠、鳥居、遠景杉林、幟＋道具、和紙層。RNG 固定種子＝可重現。
## 描邊後處理 quad 執行期掛到當前相機；_apply_ink() 把玩家 mesh 套水墨 toon。
## shader 來源＝assets/shaders/okami/*.gdshader（由水墨 look-dev 原型正式化而來）。

const TOON_SHADER := preload("res://assets/shaders/okami/ink_toon.gdshader")
const GROUND_SHADER := preload("res://assets/shaders/okami/ink_ground.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/okami/ink_outline.gdshader")
const PAPER_SHADER := preload("res://assets/shaders/okami/ink_paper.gdshader")

func _ready() -> void:
	_build_env(self)
	_build_street(self)
	_build_torii(self)
	_build_lanterns(self)
	_build_stone_lanterns(self)
	_build_backdrop(self)
	_build_props(self)
	# _build_paper_overlay()  # 暫拿掉和紙顆粒 overlay（使用者覺得灰灰破壞品質）看效果
	_attach_outline_deferred()
	print("SHRINE_STREET ready")

# ── 描邊：延幀掛到當前相機（CameraRig 在自己的 _ready 才 make_current）──
func _attach_outline_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_attach_outline_to_camera()
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_apply_ink(player)
		print("SHRINE_INK_PLAYER ok")

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

## 玩家材質：保留 Meshy 貼圖(新 okami 立繪模型)+修透明消光，靠場景描邊給墨邊(同 NpcFigure)。
## (舊版套平塗灰 toon；使用者要求改保貼圖讓主角品質透出。)
func _apply_ink(node: Node) -> void:
	for c in node.get_children():
		_apply_ink(c)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var sc: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in sc:
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var b := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				b.albedo_color.a = 1.0
				b.roughness = 1.0
				b.metallic = 0.0
				b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, b)

# ── 材質 helper ─────────────────────────────────────────
func _toon_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	return m

func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _toon_mat(color)
	root.add_child(mi)
	return mi

func _roof(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = _toon_mat(color)
	root.add_child(mi)

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

# ── 環境 ────────────────────────────────────────────────
func _build_env(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.91, 0.87, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.83, 0.76)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.86, 0.77)
	env.fog_density = 0.0015
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root.add_child(sun)

# ── 場景 ────────────────────────────────────────────────
func _build_street(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(40, 0.2, 70)
	ground.mesh = gb
	ground.position = Vector3(0, -0.1, -12)
	ground.material_override = _ground_mat()   # 石板紋專屬 shader
	root.add_child(ground)
	var floor_body := StaticBody3D.new()
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 70)
	cshape.shape = box
	floor_body.add_child(cshape)
	floor_body.position = Vector3(0, -0.1, -12)
	root.add_child(floor_body)
	var inks := [Color(0.17, 0.16, 0.19), Color(0.20, 0.19, 0.22), Color(0.14, 0.13, 0.16)]
	var accents := [Color(0.55, 0.14, 0.11), Color(0.18, 0.36, 0.30), Color(0.45, 0.38, 0.16)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var z := 2.0
	var i := 0
	while z > -40.0:
		var hgt := rng.randf_range(3.5, 6.5)   # 矮店家(1-2層)讓大屋頂入鏡
		var w := rng.randf_range(4.0, 6.0)
		var d := rng.randf_range(4.5, 6.5)
		for side in [-1, 1]:
			var x := float(side) * rng.randf_range(7.5, 9.0)
			_box(root, Vector3(x, hgt * 0.5, z), Vector3(w, hgt, d), inks[i % inks.size()])
			var roof_h := rng.randf_range(1.6, 2.6)
			_roof(root, Vector3(x, hgt + roof_h * 0.5, z), Vector3(w + 1.4, roof_h, d + 1.4), Color(0.15, 0.14, 0.16))
			# 店面（朝街那面）：暖光店內＋暖簾＋披簷
			var fx := x - float(side) * (w * 0.5 + 0.05)
			var sh := minf(hgt, 3.0)
			var lit := MeshInstance3D.new()
			var lq := BoxMesh.new()
			lq.size = Vector3(0.12, sh * 0.72, d * 0.62)
			lit.mesh = lq
			lit.position = Vector3(fx, sh * 0.45, z)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(1.0, 0.78, 0.46)
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.72, 0.38)
			lm.emission_energy_multiplier = 1.5
			lit.material_override = lm
			root.add_child(lit)
			var norens := [Color(0.16, 0.20, 0.32), Color(0.50, 0.16, 0.13), Color(0.20, 0.22, 0.24)]
			_box(root, Vector3(fx - float(side) * 0.10, sh * 0.80, z), Vector3(0.08, sh * 0.32, d * 0.64), norens[i % norens.size()])
			_roof(root, Vector3(fx - float(side) * 0.55, sh + 0.05, z), Vector3(1.3, 0.8, d * 0.95), Color(0.13, 0.12, 0.14))
			# 店面木格(格子戸)＋掛看板
			for bi in range(4):
				var bz := z - d * 0.26 + float(bi) * (d * 0.52 / 3.0)
				_box(root, Vector3(fx - float(side) * 0.04, sh * 0.45, bz), Vector3(0.05, sh * 0.66, 0.05), Color(0.12, 0.11, 0.12))
			_box(root, Vector3(fx - float(side) * 0.04, sh * 0.62, z), Vector3(0.05, 0.06, d * 0.58), Color(0.12, 0.11, 0.12))
			var sign_col: Color = [Color(0.13, 0.12, 0.13), Color(0.30, 0.13, 0.10)][i % 2]
			_box(root, Vector3(fx - float(side) * 0.52, sh - 0.25, z), Vector3(0.06, 0.55, 0.8), sign_col)
			if i % 2 == 0:
				_box(root, Vector3(x, hgt + 0.4, z), Vector3(w + 1.2, 0.8, d + 1.2), accents[i % accents.size()])
			if i % 3 == 0:
				var ax := x - float(side) * (w * 0.5 + 0.15)
				_box(root, Vector3(ax, hgt * 0.55, z - d * 0.2), Vector3(0.2, hgt * 0.5, 1.0), accents[(i + 1) % accents.size()])
			i += 1
		z -= rng.randf_range(7.0, 9.0)

func _build_torii(root: Node3D) -> void:
	var red := Color(0.58, 0.15, 0.12)
	var zt := -14.0
	for side in [-1, 1]:
		_box(root, Vector3(float(side) * 4.6, 5.0, zt), Vector3(0.7, 10.0, 0.7), red)
	_box(root, Vector3(0, 9.8, zt), Vector3(11.5, 0.8, 0.9), red)
	_box(root, Vector3(0, 8.4, zt), Vector3(9.6, 0.5, 0.7), red)

func _build_lanterns(root: Node3D) -> void:
	var z := 0.0
	while z > -34.0:
		for side in [-1, 1]:
			var x := float(side) * 5.6
			_box(root, Vector3(x, 2.0, z), Vector3(0.25, 4.0, 0.25), Color(0.12, 0.11, 0.13))
			var glow := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.55
			sm.height = 1.1
			glow.mesh = sm
			glow.position = Vector3(x, 4.2, z)
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(1.0, 0.80, 0.42)
			gm.emission_enabled = true
			gm.emission = Color(1.0, 0.74, 0.34)
			gm.emission_energy_multiplier = 2.4
			glow.material_override = gm
			root.add_child(glow)
			var l := OmniLight3D.new()
			l.position = Vector3(x, 4.2, z)
			l.light_color = Color(1.0, 0.82, 0.5)
			l.light_energy = 1.6
			l.omni_range = 9.0
			root.add_child(l)
		z -= 8.0

func _build_backdrop(root: Node3D) -> void:
	# 遠景：杉林剪影＋山，沒入霧與紙色（水墨遠則淡）
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for mx in [-16.0, -4.0, 9.0]:
		var mh := rng.randf_range(20.0, 30.0)
		_roof(root, Vector3(mx, mh * 0.5 - 2.0, -52.0), Vector3(rng.randf_range(22.0, 34.0), mh, 6.0), Color(0.30, 0.30, 0.33))
	var x := -18.0
	while x < 18.0:
		var th := rng.randf_range(10.0, 20.0)
		var tree := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = rng.randf_range(0.9, 1.6)
		cyl.height = th
		cyl.radial_segments = 6
		tree.mesh = cyl
		tree.position = Vector3(x + rng.randf_range(-1.2, 1.2), th * 0.5 - 0.5, rng.randf_range(-46.0, -42.0))
		tree.material_override = _toon_mat(Color(0.17, 0.18, 0.18))
		root.add_child(tree)
		x += rng.randf_range(1.6, 2.6)

func _build_stone_lanterns(root: Node3D) -> void:
	# 石燈籠：基座＋竿＋火袋(暖光)＋笠
	var stone := Color(0.34, 0.33, 0.30)
	var z := -3.0
	while z > -30.0:
		for side in [-1, 1]:
			var x := float(side) * 4.2
			_box(root, Vector3(x, 0.35, z), Vector3(0.9, 0.7, 0.9), stone)
			_box(root, Vector3(x, 1.1, z), Vector3(0.35, 0.8, 0.35), stone)
			var fb := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.7, 0.6, 0.7)
			fb.mesh = bm
			fb.position = Vector3(x, 1.7, z)
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(1.0, 0.82, 0.5)
			em.emission_enabled = true
			em.emission = Color(1.0, 0.72, 0.34)
			em.emission_energy_multiplier = 2.0
			fb.material_override = em
			root.add_child(fb)
			_roof(root, Vector3(x, 2.2, z), Vector3(1.1, 0.5, 1.1), stone)
			var l := OmniLight3D.new()
			l.position = Vector3(x, 1.7, z)
			l.light_color = Color(1.0, 0.8, 0.48)
			l.light_energy = 1.2
			l.omni_range = 6.0
			root.add_child(l)
		z -= 9.0

func _build_props(root: Node3D) -> void:
	# 幟(直幡)＋路邊道具(酒樽/木箱)增加生活感與垂直節奏
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var z := -1.0
	var flip := 0
	while z > -28.0:
		var side := 1 if flip % 2 == 0 else -1
		var x := float(side) * 5.2
		_box(root, Vector3(x, 2.4, z), Vector3(0.12, 4.8, 0.12), Color(0.10, 0.10, 0.12))
		var cloth: Color = [Color(0.62, 0.17, 0.13), Color(0.86, 0.83, 0.74)][flip % 2]
		_box(root, Vector3(x + float(side) * 0.35, 3.0, z), Vector3(0.06, 3.0, 0.7), cloth)
		flip += 1
		z -= rng.randf_range(6.0, 8.0)
	var k := 0
	z = -5.0
	while z > -26.0:
		var side2 := -1 if k % 2 == 0 else 1
		var bx := float(side2) * 3.4
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.9
		bar.mesh = cm
		bar.position = Vector3(bx, 0.45, z)
		bar.material_override = _toon_mat(Color(0.40, 0.30, 0.18))
		root.add_child(bar)
		_box(root, Vector3(bx + float(side2) * 0.9, 0.35, z + 0.4), Vector3(0.7, 0.7, 0.7), Color(0.44, 0.34, 0.22))
		_box(root, Vector3(bx + float(side2) * 0.9, 0.95, z + 0.5), Vector3(0.5, 0.5, 0.5), Color(0.40, 0.31, 0.20))
		k += 1
		z -= rng.randf_range(7.0, 9.0)
