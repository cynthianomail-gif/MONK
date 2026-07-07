extends Node3D
## 程式化「軍火庫區」環境（黑道軍火倉庫街，幾何盒體＋stylized 程序材質）。
## 與 ShrineStreet 同架構、同一套 stylized shader（去水墨：無 toon 色階/描邊），
## 換暗鋼鐵調＋軍火庫內容：浪板鐵皮倉庫(真凹凸+鏽斑)、武器箱/油桶/武器架、
## 紅燈籠、街尾熔鑄爐建築(地標＝Boss 巢)、濕石板路反燈光、煙硝暗霧。

const PLASTER_SHADER := preload("res://assets/shaders/stylized/plaster.gdshader")
const COBBLE_SHADER := preload("res://assets/shaders/stylized/cobblestone.gdshader")
const CORRUGATED_SHADER := preload("res://assets/shaders/stylized/corrugated_metal.gdshader")

func _ready() -> void:
	add_to_group("minimap_streets")
	_build_env(self)
	_build_district(self)
	_build_forge(self)
	_build_lanterns(self)
	_build_props(self)
	_build_parlor_door(self)
	_build_backdrop(self)
	_build_ambient(self)
	_fix_player_deferred()
	if OS.is_debug_build():
		print("ARMORY_DISTRICT ready")

## 軍火庫固定夜調(見 _build_env)，環境音也固定單一軌，不像神社街分時段。音檔缺就靜默跳過。
func _build_ambient(root: Node3D) -> void:
	var path := "res://assets/audio/ambient/ambient_armory.ogg"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.volume_db = -10.0
	player.stream = stream
	root.add_child(player)
	player.play()

## 小地圖街道帶（世界 XZ）：倉庫夾出的直街，x∈[-6,6]、z 從入口到熔鑄爐前。
func minimap_streets() -> Array:
	return [Rect2(-6.0, -32.0, 12.0, 38.0)]

# ── 玩家材質修正：延幀等玩家進場 ──
func _fix_player_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_fix_figure_materials(player)
		if OS.is_debug_build():
			print("ARMORY_PLAYER_MAT ok")

## 玩家材質：保留 Meshy 貼圖＋修透明雷，消光防塑膠感。
func _fix_figure_materials(node: Node) -> void:
	for c in node.get_children():
		_fix_figure_materials(c)
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
func _flat_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLASTER_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = COBBLE_SHADER
	m.set_shader_parameter("albedo", Color(0.30, 0.29, 0.31))   # 暗石板
	m.set_shader_parameter("stone_size", 1.1)
	m.set_shader_parameter("bump", 0.45)                        # 夜街壓低凹凸，免得每顆變發亮鈕扣
	m.set_shader_parameter("rough_stone", 0.45)                 # 微濕面，反燈籠/爐火光
	m.set_shader_parameter("mortar_darken", 0.55)
	return m

func _corrugated_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CORRUGATED_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rib_w", 0.38)   # 波距放寬＋凹凸壓低：細波在遠處會閃摩爾紋
	m.set_shader_parameter("bump", 0.3)
	return m

## 2026-07-08 邊界破綻修正：遠景「圍裙」地面——一片遠比地面網格大、貼地略低於
## 主地面的純視覺(無碰撞)平面，蓋住地面邊緣以外的所有方向。街區沒有隱形邊界牆
## （唯一約束是地面網格本身），回頭看南口/東西側看倉庫間隙都會露出網格邊緣外的
## 純色天空虛空——加這片圍裙用低調暗色配合既有霧把接縫藏掉，不新增碰撞、
## 不改任何既有牆/相機遮擋/TIME 相關參數。
func _build_ground_skirt(root: Node3D) -> void:
	var skirt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)   # 遠超霧視距，接縫不會露餡
	skirt.mesh = pm
	skirt.position = Vector3(0, -0.35, -12.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.15, 0.16)   # 暗鋼灰，比主地面(0.30)略暗，霧會再壓一層
	m.roughness = 0.95
	skirt.material_override = m
	root.add_child(skirt)

func _steel_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _corrugated_mat(color)   # 浪板鐵皮一條條
	root.add_child(mi)

## 相機遮擋體（碰撞層2）：只給 CameraRig spring-arm 射線用，不擋角色（角色 mask=1）。
func _cam_blocker(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	root.add_child(body)

func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _flat_mat(color)
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
	mi.material_override = _flat_mat(color)
	root.add_child(mi)

func _omni(root: Node3D, pos: Vector3, col: Color, energy: float, rng_: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	root.add_child(l)

# ── 環境：夜、暗鋼鐵、煙硝、爐火暖光透出 ──────────────────
func _build_env(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.12, 0.14)            # 暗煙夜空
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.33, 0.38)
	env.ambient_light_energy = 0.85                            # 去 toon 後暗面更暗，補一點環境光
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.18                             # 爐火/燈籠暈但不過爆
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.18, 0.17)            # 暖煙硝
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -38, 0)
	moon.light_color = Color(0.62, 0.64, 0.74)               # 冷弱月光
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	moon.shadow_normal_bias = 3.0
	moon.shadow_blur = 2.5   # 夜街軟影
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
	_build_ground_skirt(root)

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
			_cam_blocker(root, Vector3(x, hgt * 0.5 + 0.25, z), Vector3(w, hgt + 0.5, d))
			# 低矮單斜鐵皮頂(略高一側)
			_box(root, Vector3(x, hgt + 0.25, z), Vector3(w + 0.6, 0.5, d + 0.6), Color(0.14, 0.13, 0.15))
			var fx := x - float(side) * (w * 0.5 + 0.05)
			# 捲門洞口＋裡頭微弱暖光
			_box(root, Vector3(fx, 1.4, z), Vector3(0.12, 2.6, d * 0.5), Color(0.08, 0.08, 0.09))
			_emissive(root, Vector3(fx - float(side) * 0.05, 1.2, z), Vector3(0.06, 1.8, d * 0.42), Color(0.55, 0.28, 0.14), 0.55)   # 門內微光：壓暗免得像大螢幕
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
## Hero 精模(magnific 水墨圖→Meshy image-to-3d)優先；缺檔 fallback 程式盒體。
const FORGE_GLB := "res://assets/3d/landmarks/forge.glb"
const FORGE_H := 12.0

func _build_forge(root: Node3D) -> void:
	var zf := -22.0
	if ResourceLoader.exists(FORGE_GLB):
		var forge := (load(FORGE_GLB) as PackedScene).instantiate()
		root.add_child(forge)
		_fix_glb_materials(forge)
		var aabb := _merged_aabb(forge)
		if aabb.size.y > 0.01:
			var sc := FORGE_H / aabb.size.y
			forge.scale = Vector3(sc, sc, sc)
			forge.position = Vector3(-aabb.get_center().x * sc, -aabb.position.y * sc, zf - aabb.get_center().z * sc)
		_cam_blocker(root, Vector3(0, FORGE_H * 0.5, zf), Vector3(12.0, FORGE_H, 8.0))
		if OS.is_debug_build():
			print("FORGE_HERO ok")
	else:
		push_warning("ArmoryDistrict: 熔鑄爐模型不存在 %s(用程式盒體)" % FORGE_GLB)
		_steel_box(root, Vector3(0, 5.5, zf), Vector3(12.0, 11.0, 7.0), Color(0.18, 0.17, 0.19))
		_cam_blocker(root, Vector3(0, 5.5, zf), Vector3(12.0, 11.0, 7.0))
		_box(root, Vector3(3.5, 12.5, zf), Vector3(1.2, 6.0, 1.2), Color(0.12, 0.11, 0.13))   # 煙囪
		_box(root, Vector3(0, 3.0, zf + 3.6), Vector3(5.0, 6.0, 0.6), Color(0.10, 0.10, 0.11))   # 爐口拱
		_emissive(root, Vector3(0, 2.6, zf + 3.9), Vector3(3.2, 3.6, 0.4), Color(1.0, 0.45, 0.14), 2.2)
		_emissive(root, Vector3(0, 0.7, zf + 4.2), Vector3(4.4, 0.5, 0.5), Color(1.0, 0.40, 0.12), 1.7)   # 爐口下熔光潑地
	# 爐火暖光打亮整條街尾＋飛濺火星（精模/盒體共用）
	_omni(root, Vector3(0, 3.0, zf + 4.5), Color(1.0, 0.46, 0.18), 3.4, 24.0)
	_omni(root, Vector3(0, 1.0, zf + 6.0), Color(1.0, 0.40, 0.16), 2.0, 14.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for s in range(14):
		var sx := rng.randf_range(-2.2, 2.2)
		var sy := rng.randf_range(4.0, 9.0)
		_emissive(root, Vector3(sx, sy, zf + 3.8), Vector3(0.09, 0.09, 0.09), Color(1.0, 0.7, 0.3), 3.0)

## 修 Meshy 材質（同 npc_figure：關透明+消光、保貼圖）。
func _fix_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in n:
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var b := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				b.albedo_color.a = 1.0
				b.roughness = 1.0
				b.metallic = 0.0
				b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, b)
	for c in node.get_children():
		_fix_glb_materials(c)

func _merged_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var a := mi.global_transform * mi.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		for c in n.get_children():
			stack.append(c)
	return aabb

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

# ── 地下遊藝場入口(東側路邊，配 map_npcs 的 parlor_entrance 觸發點) ──
## 下行樓梯口造型：門框＋暗洞＋下沉階梯暗示＋紅燈籠＋「遊」字暖招牌。
func _build_parlor_door(root: Node3D) -> void:
	var dz := -10.5
	var dx := 5.2
	var dark := Color(0.12, 0.11, 0.13)
	# 門框（兩柱一楣）
	_box(root, Vector3(dx, 1.3, dz - 1.0), Vector3(0.25, 2.6, 0.25), dark)
	_box(root, Vector3(dx, 1.3, dz + 1.0), Vector3(0.25, 2.6, 0.25), dark)
	_box(root, Vector3(dx, 2.7, dz), Vector3(0.25, 0.3, 2.2), dark)
	# 門洞暗面＋往下階梯（三階遞降的薄板，暗示下行）
	_box(root, Vector3(dx + 0.15, 1.25, dz), Vector3(0.1, 2.3, 1.8), Color(0.05, 0.05, 0.06))
	for s in range(3):
		_box(root, Vector3(dx - 0.35 - float(s) * 0.35, 0.06 - float(s) * 0.045, dz), Vector3(0.35, 0.1, 1.6), Color(0.17, 0.16, 0.18))
	# 招牌（暖光；能量壓低避免 glow 過曝成白）＋門口紅燈籠
	_emissive(root, Vector3(dx - 0.2, 2.35, dz), Vector3(0.15, 0.5, 1.6), Color(0.95, 0.62, 0.24), 1.05)
	_emissive(root, Vector3(dx - 0.3, 1.9, dz - 1.2), Vector3(0.38, 0.5, 0.38), Color(0.85, 0.20, 0.12), 1.7)
	_omni(root, Vector3(dx - 0.5, 2.0, dz), Color(1.0, 0.62, 0.30), 1.6, 7.0)

# ── 遠景：暗工業剪影＋煙囪＋煙(取代杉林) ──────────────────
## 2026-07-08 邊界破綻修正：原本只在北端(z∈[-46,-40])擺剪影，回頭看南口(z>23附近)
## 或直視東西側(x→±20)都會穿過地面網格看見純色天空虛空（GPU 截圖驗到，見
## D:\monk\_boundary_audit\armory_entrance_yaw180_*.png 等）。補南端＋東西側剪影列，
## 同款暗工業剪影 box，純視覺無碰撞（同北端既有寫法），把四個方向的地平線都用
## 建築剪影墊住，霧再把細節糊掉。
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
	# 南端剪影（回頭看入口方向的地平線）
	var xs := -18.0
	while xs < 18.0:
		var hs := rng.randf_range(7.0, 15.0)
		_box(root, Vector3(xs, hs * 0.5 - 1.0, rng.randf_range(26.0, 32.0)), Vector3(rng.randf_range(3.0, 6.0), hs, 3.0), Color(0.17, 0.17, 0.19))
		xs += rng.randf_range(3.5, 5.5)
	# 東西側剪影（直視街寬方向的地平線；街區可走寬度內建築約在 x∈[±7.5,±16]，
	# 剪影擺在更外側 x=±26 當遠景輪廓）
	var zs := -44.0
	while zs < 26.0:
		var hz := rng.randf_range(7.0, 16.0)
		_box(root, Vector3(-26.0, hz * 0.5 - 1.0, zs), Vector3(3.0, hz, rng.randf_range(3.0, 5.0)), Color(0.17, 0.17, 0.19))
		_box(root, Vector3(26.0, hz * 0.5 - 1.0, zs + rng.randf_range(-2.0, 2.0)), Vector3(3.0, hz, rng.randf_range(3.0, 5.0)), Color(0.16, 0.16, 0.18))
		zs += rng.randf_range(6.0, 9.0)
