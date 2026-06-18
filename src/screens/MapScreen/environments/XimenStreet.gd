extends Node3D
## 程式化「西門霓虹街」環境（approach A：盒體幾何＋AI 貼圖＋霓虹雨霧）。
## 在 _ready() 動態建：濕柏油地面（車道＋人行道＋水漥）、兩排盒體樓
## （每棟貼一張「完整單棟大樓」AI 圖，招牌烤進圖內、不垂直 tile、不翻面）、
## 彩色光池、暗色 bloom＋體積霧＋濕地反射、雨。
## 街沿 Z 軸延伸（玩家沿 Z 走），樓在 ±X 兩側。可掛進 MapScreen 或獨立原型場景。

const TEX_DIR := "res://assets/3d/environments/ximen/"
const PROP_DIR := "res://assets/3d/props/"

const STREET_HALF_LEN := 34.0   # 街沿 Z 從 -34 到 +34
const STREET_HALF_W := 7.0      # 樓立面在 x = ±7（街寬 14）
const BUILDINGS_PER_SIDE := 11   # 加密（原 7，巷縫變窄更像街谷）
const GF_H := 3.6                # 一樓店面高度
const RECESS := 0.4              # 一樓店門內凹深度（做出入口立體感）

# 模組化零件圖庫（不再用「整棟一張圖」；改用乾淨可重複/去背的零件在 3D 組裝）
var _walls: Array = []       # 樓身可重複窗牆貼圖
var _signs_h: Array = []     # 橫招牌（黑底發光 cutout，加色混合）
var _signs_v: Array = []     # 直立招牌（黑底發光 cutout）
var _awning_tex: Texture2D   # 遮雨棚
var _shops: Array = []       # 一樓店門櫥窗（多種，隨機輪替）
var _ground_tex: Texture2D
var _peds: Array = []        # 路人 sprite 貼圖（去背）
var _crowd: Array = []       # 走動中的路人 {node, vz}

func _ready() -> void:
	# 載入模組化零件：窗牆 wall_*、橫/直招牌 sign_h_*/sign_v_*、遮雨棚、店門
	for i in range(1, 13):
		var w := _load(TEX_DIR + "wall_%02d.png" % i)
		if w: _walls.append(w)
		var sh := _load(TEX_DIR + "sign_h_%02d.png" % i)
		if sh: _signs_h.append(sh)
		var sv := _load(TEX_DIR + "sign_v_%02d.png" % i)
		if sv: _signs_v.append(sv)
	_awning_tex = _load(TEX_DIR + "awning_01.png")
	for i in range(1, 9):
		var sf := _load(TEX_DIR + "shopfront_%02d.png" % i)
		if sf: _shops.append(sf)
	for i in range(1, 13):
		var p := _load(TEX_DIR + "ped_%02d.png" % i)
		if p: _peds.append(p)
	_ground_tex = _load(TEX_DIR + "ground_wet.png")
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_backdrop()
	_build_props()
	_build_crowd()
	_build_rain()
	# _build_postfx()  # 卡通描邊暫關（canvas normal hint 把畫面蓋掉，待單獨 debug）

func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# ── 大氣：明亮 cel 夜霓虹（高環境光平亮、薄霾、鮮彩；丟掉厚 noir 霧）──
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.22)   # 暮藍夜空（非死黑）＝亮、可讀
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.82)
	env.ambient_light_energy = 0.85                  # 高環境光＝cel 平亮、整體可讀
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Bloom：讓亮霓虹暈開
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.9
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 0.6)
	env.set("glow_levels/5", 0.3)
	# 輕薄遠景霾（不要厚 noir 霧，街要看得清）
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.34, 0.5)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.0
	# 鮮明高彩（cel 感）
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.28
	env.adjustment_brightness = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 柔和主光（cel 平光，不要硬陰影）
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.light_energy = 0.5
	sun.rotation_degrees = Vector3(-60, 35, 0)
	sun.shadow_enabled = false
	add_child(sun)

# ── 濕柏油地面：車道＋兩側人行道＋零星水漥（拆分材質＋打散重複＋濕地反射）──
func _build_ground() -> void:
	var total_len := STREET_HALF_LEN * 2.0 + 12.0
	var walk_w := 2.0
	var road_w := STREET_HALF_W * 2.0 - walk_w * 2.0   # 中央車道（兩側讓給人行道，總寬仍到立面）

	# 車道（無縫濕柏油，等比 uv 免拉伸；無特徵貼圖重複不顯眼）
	var road := PlaneMesh.new()
	road.size = Vector2(road_w, total_len)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = _ground_tex
	rmat.albedo_color = Color(1.7, 1.7, 1.85)   # >1 提亮過暗的柏油貼圖到中間調，彩色燈才鋪得開成濕街光暈
	rmat.uv1_scale = Vector3(road_w / 3.2, total_len / 3.2, 1)
	rmat.uv1_offset = Vector3(0.13, 0.27, 0)
	rmat.metallic = 0.0
	rmat.roughness = 0.34              # 濕亮但不全鏡面（掠角不過曝），霓虹反射成縱向光條
	rmat.metallic_specular = 0.5
	road.material = rmat
	var rmi := MeshInstance3D.new()
	rmi.mesh = road
	add_child(rmi)

	# 兩側人行道（同圖、uv 偏移＋壓暗壓糙做區隔，讀成路緣步道）
	for s in [-1.0, 1.0]:
		var walk := PlaneMesh.new()
		walk.size = Vector2(walk_w, total_len)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_texture = _ground_tex
		wmat.albedo_color = Color(0.66, 0.66, 0.7)
		wmat.uv1_scale = Vector3(walk_w / 2.2, total_len / 2.2, 1)
		wmat.uv1_offset = Vector3(0.5, 0.0, 0)
		wmat.roughness = 0.5           # 人行道較不反光（仍帶點濕）
		walk.material = wmat
		var wmi := MeshInstance3D.new()
		wmi.mesh = walk
		wmi.position = Vector3(s * (road_w * 0.5 + walk_w * 0.5), 0.005, 0.0)
		add_child(wmi)

	# （亮 cel 街移除 noir 暗水漥＝在無反射的亮地面上會變黑洞）

	# 地面碰撞（單一平面，視覺分層不影響行走）
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(44, 1, total_len)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)

# ── 兩排「組裝式」店面（樓身窗牆＋內凹店門＋遮雨棚＋伸出霓虹招牌）──
func _build_buildings() -> void:
	if _walls.is_empty():
		return
	var step := (STREET_HALF_LEN * 2.0) / float(BUILDINGS_PER_SIDE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260616
	for side_v in [-1, 1]:
		var side: int = side_v
		for i in BUILDINGS_PER_SIDE:
			var z := -STREET_HALF_LEN + step * (i + 0.5)
			var width: float = minf(step - rng.randf_range(0.6, 1.4), 6.4)
			# 天際線起伏：高/矮樓混搭（窗牆可平鋪到任意高度）
			var h: float = rng.randf_range(15.0, 23.0) if rng.randf() < 0.45 else rng.randf_range(8.0, 13.0)
			var depth := rng.randf_range(6.0, 9.0)
			_make_building(side, z, width, h, depth, rng)

func _make_building(side: int, z: float, width: float, h: float, depth: float, rng: RandomNumberGenerator) -> void:
	var fs := float(side)
	var front_x: float = fs * STREET_HALF_W           # facade 立面線（樓身窗牆／遮雨棚基準）
	var box_front: float = front_x + fs * RECESS       # 盒身＋一樓店門退到 RECESS 後＝內凹
	var inward := -fs                                  # 朝街心的方向

	# 1) 暗盒身（碰撞＋遮擋背景），front 退到 RECESS 後
	var center_x: float = box_front + fs * (depth * 0.5)
	var box := BoxMesh.new()
	box.size = Vector3(depth, h, width)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.10)
	dark.roughness = 1.0
	box.material = dark
	var bm := MeshInstance3D.new()
	bm.mesh = box
	bm.position = Vector3(center_x, h * 0.5, z)
	add_child(bm)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(depth, h, width)
	col.shape = shape
	body.position = Vector3(center_x, h * 0.5, z)
	body.add_child(col)
	add_child(body)

	# 2) 樓身窗牆（GF_H..h），齊 facade 線、依層垂直平鋪
	var wall_h: float = maxf(h - GF_H, 1.5)
	var wq := QuadMesh.new()
	wq.size = Vector2(width, wall_h)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_texture = _walls[rng.randi() % _walls.size()]
	var floors: float = maxf(1.0, roundf(wall_h / 3.0))
	wmat.uv1_scale = Vector3(maxf(1.0, width / 4.0), floors, 1)
	wmat.roughness = 0.95
	wq.material = wmat
	var wmi := MeshInstance3D.new()
	wmi.mesh = wq
	wmi.position = Vector3(front_x + inward * 0.02, GF_H + wall_h * 0.5, z)
	wmi.rotation_degrees = Vector3(0, -90 * side, 0)
	add_child(wmi)

	# 3) 一樓店門（0..GF_H）＝內凹發光櫥窗（unshaded 自亮，多種隨機輪替）
	if not _shops.is_empty():
		var sq := QuadMesh.new()
		sq.size = Vector2(width * 0.96, GF_H)
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_texture = _shops[rng.randi() % _shops.size()]
		sq.material = smat
		var smi := MeshInstance3D.new()
		smi.mesh = sq
		smi.position = Vector3(box_front + inward * 0.02, GF_H * 0.5, z)
		smi.rotation_degrees = Vector3(0, -90 * side, 0)
		add_child(smi)

	# 4) 遮雨棚：水平面板從 facade 伸出街心 ~1.3m（做視差深度）
	if _awning_tex:
		var aw := QuadMesh.new()
		aw.size = Vector2(1.3, width)        # x=伸出深度，y=沿樓寬
		var amat := StandardMaterial3D.new()
		amat.albedo_texture = _awning_tex
		amat.uv1_scale = Vector3(1, maxf(1.0, width / 2.5), 1)
		amat.cull_mode = BaseMaterial3D.CULL_DISABLED
		amat.roughness = 0.9
		aw.material = amat
		var ami := MeshInstance3D.new()
		ami.mesh = aw
		ami.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # 躺平＝水平遮雨棚
		ami.position = Vector3(front_x + inward * 0.6, GF_H + 0.08, z)
		add_child(ami)

	# 5) 橫招牌（黑底加色發光 cutout）貼 facade 上、遮雨棚上方
	if not _signs_h.is_empty():
		_add_sign(_signs_h[rng.randi() % _signs_h.size()], Vector2(width * 0.82, 1.0),
			Vector3(front_x + inward * 0.06, GF_H + 0.95, z), Vector3(0, -90 * side, 0), false)

	# 6) 直立招牌（垂直、垂直 facade 伸出街心＝沿街可讀）
	if not _signs_v.is_empty() and rng.randf() < 0.75:
		var sv_h: float = minf(h - GF_H - 1.0, rng.randf_range(2.6, 4.2))
		var yv: float = GF_H + 1.6 + sv_h * 0.5
		_add_sign(_signs_v[rng.randi() % _signs_v.size()], Vector2(1.0, sv_h),
			Vector3(front_x + inward * 1.0, yv, z), Vector3(0, 0, 0), true)

	# 7) 店門暖光（照內凹櫥窗＋地面）
	var omni := OmniLight3D.new()
	var cols := [Color(1.0, 0.7, 0.4), Color(1.0, 0.45, 0.6), Color(0.4, 0.8, 1.0), Color(0.9, 0.8, 0.5)]
	omni.light_color = cols[rng.randi() % cols.size()]
	omni.light_energy = rng.randf_range(1.4, 2.2)
	omni.omni_range = 8.5
	omni.position = Vector3(front_x + inward * 1.0, GF_H * 0.8, z)
	add_child(omni)

# 街頭/街尾遠景背板：填掉盡頭黑洞，像街繼續延伸成一片燈海
func _build_backdrop() -> void:
	if _walls.is_empty():
		return
	var tex: Texture2D = _walls[_walls.size() - 1]   # 用招牌牆＝遠處燈海
	for end_z in [-STREET_HALF_LEN - 3.0, STREET_HALF_LEN + 3.0]:
		var q := QuadMesh.new()
		q.size = Vector2(STREET_HALF_W * 2.0 + 6.0, 20.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = tex
		m.albedo_color = Color(0.45, 0.45, 0.55)   # 壓暗＝遠景
		m.uv1_scale = Vector3(3, 4, 1)
		q.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = Vector3(0, 9.0, end_z)
		mi.rotation_degrees = Vector3(0, 0 if end_z < 0 else 180, 0)
		add_child(mi)

# ── 街道道具（Meshy 真 3D）：販賣機擺人行道靠樓側、面向街心 ──
func _build_props() -> void:
	var vending := _load_scene(PROP_DIR + "vending_machine_01.glb")
	var aframe := _load_scene(PROP_DIR + "aframe_sign_01.glb")
	var bike := _load_scene(PROP_DIR + "bicycle_01.glb")
	var road_w := STREET_HALF_W * 2.0 - 2.0 * 2.0   # 同 _build_ground 的車道寬=10
	var walk_w := 2.0
	var wx := road_w * 0.5 + walk_w * 0.5            # 人行道中心 x≈6
	# Meshy 正面預設 +Z；面向街心＝右側(side+1) 轉 -90、左側(side-1) 轉 +90
	# 販賣機（自發光顯示窗，另配冷色 omni 染地）
	for sp in [{"z": -6.0, "side": 1}, {"z": -16.0, "side": -1}, {"z": -26.0, "side": 1}]:
		var side: float = float(sp["side"])
		var x: float = (wx - 0.25) * side
		_place_prop(vending, Vector3(x, 0.0, sp["z"]), -90.0 * side)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.5, 0.85, 1.0)
		glow.light_energy = 1.8
		glow.omni_range = 4.5
		glow.position = Vector3(x - 0.7 * side, 1.2, sp["z"])
		add_child(glow)
	# A 字立牌：海報面朝街心
	_place_prop(aframe, Vector3(-(wx - 0.35), 0.0, -8.0), 90.0)
	_place_prop(aframe, Vector3(wx - 0.35, 0.0, -9.5), -90.0)
	# 腳踏車：靠牆停、車身與街平行（長軸 X→轉 90 沿 Z），側面朝街
	_place_prop(bike, Vector3(wx - 0.1, 0.0, -12.5), 90.0)
	_place_prop(bike, Vector3(-(wx - 0.1), 0.0, -13.0), 90.0)

# 通用：instantiate GLB → 修材質 → 定位/朝向 → 掛入
func _place_prop(scene: PackedScene, pos: Vector3, yaw_deg: float) -> Node3D:
	if scene == null:
		return null
	var n := scene.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees = Vector3(0, yaw_deg, 0)
	_fix_meshy_materials(n)
	add_child(n)
	return n

func _load_scene(path: String) -> PackedScene:
	return load(path) as PackedScene if ResourceLoader.exists(path) else null

# Meshy GLB 的 base color 常帶 alpha，被 Godot 判成透明 → 整顆消失。
# 強制不透明、albedo alpha 補回 1（保留 emission 發光面）。
func _fix_meshy_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat = mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					var bm := mat as BaseMaterial3D
					bm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					var c := bm.albedo_color
					c.a = 1.0
					bm.albedo_color = c
	for ch in node.get_children():
		_fix_meshy_materials(ch)

# ── 路人人群：cel billboard sprite 沿街走動（讓街活起來）──
func _build_crowd() -> void:
	if _peds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in 28:
		var s := Sprite3D.new()
		s.texture = _peds[rng.randi() % _peds.size()]
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # 直立、繞 Y 面向相機
		s.shaded = false
		s.pixel_size = 0.0013                            # 768×1376 圖 → 約 1.0×1.8m
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD     # 硬邊去背、免透明排序
		var lane: float = rng.randf_range(-STREET_HALF_W + 1.2, STREET_HALF_W - 1.2)
		var pz: float = rng.randf_range(-STREET_HALF_LEN, STREET_HALF_LEN)
		s.position = Vector3(lane, 0.95, pz)
		add_child(s)
		var spd: float = rng.randf_range(1.4, 2.6)
		_crowd.append({"node": s, "vz": spd * (1.0 if rng.randf() < 0.5 else -1.0)})

func _process(delta: float) -> void:
	for c in _crowd:
		var n: Sprite3D = c["node"]
		var p := n.position
		p.z += float(c["vz"]) * delta
		if p.z > STREET_HALF_LEN:
			p.z -= STREET_HALF_LEN * 2.0
		elif p.z < -STREET_HALF_LEN:
			p.z += STREET_HALF_LEN * 2.0
		n.position = p

# 黑底發光招牌 cutout：加色混合＝黑處透明、霓虹發光
func _add_sign(tex: Texture2D, size: Vector2, pos: Vector3, rot_deg: Vector3, double_sided: bool) -> void:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD       # 黑底加色＝黑透明
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)

# ── 卡通描邊：全螢幕 depth+normal 邊緣偵測（P5/cel 的黑描邊感）──
func _build_postfx() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" + \
		"uniform sampler2D screen_tex : hint_screen_texture, filter_linear;\n" + \
		"uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;\n" + \
		"uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;\n" + \
		"const float thickness = 1.3;\n" + \
		"const float depth_edge = 0.0009;\n" + \
		"const float normal_edge = 0.5;\n" + \
		"const vec3 line_color = vec3(0.06, 0.05, 0.10);\n" + \
		"void fragment() {\n" + \
		"	vec2 px = SCREEN_PIXEL_SIZE * thickness;\n" + \
		"	vec3 base = texture(screen_tex, SCREEN_UV).rgb;\n" + \
		"	float dc = texture(depth_tex, SCREEN_UV).r;\n" + \
		"	float dr = texture(depth_tex, SCREEN_UV + vec2(px.x, 0.0)).r;\n" + \
		"	float dd = texture(depth_tex, SCREEN_UV + vec2(0.0, px.y)).r;\n" + \
		"	float dl = texture(depth_tex, SCREEN_UV - vec2(px.x, 0.0)).r;\n" + \
		"	float du = texture(depth_tex, SCREEN_UV - vec2(0.0, px.y)).r;\n" + \
		"	float de = abs(dc-dr)+abs(dc-dd)+abs(dc-dl)+abs(dc-du);\n" + \
		"	vec3 nc = texture(normal_tex, SCREEN_UV).xyz;\n" + \
		"	vec3 nr = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).xyz;\n" + \
		"	vec3 nd = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).xyz;\n" + \
		"	float ne = (1.0-dot(nc,nr)) + (1.0-dot(nc,nd));\n" + \
		"	float edge = clamp(step(depth_edge, de) + step(normal_edge, ne), 0.0, 1.0);\n" + \
		"	COLOR = vec4(mix(base, line_color, edge * 0.8), 1.0);\n" + \
		"}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	cl.add_child(rect)
	add_child(cl)

# ── 雨 ──
func _build_rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = 650
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-12, -2, -STREET_HALF_LEN - 6), Vector3(24, 30, STREET_HALF_LEN * 2 + 12))
	p.position = Vector3(0, 16, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 1.5
	pm.gravity = Vector3(0, -40, 0)
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 1, STREET_HALF_LEN)   # 只在街道上空下雨
	p.process_material = pm
	# 雨絲：細長 quad、很淡的冷色（不 billboard＝垂直線，免層疊糊白）
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.5)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.6, 0.68, 0.82, 0.16)
	streak.material = rm
	p.draw_pass_1 = streak
	add_child(p)
