extends Node3D
## HD-2D 西門街世界建構器（八方旅人式）：厚塗 2D 立板擺進真 3D 景深。
## 本節點建整個「世界」：環境、地面、建築立板（遞遠霓虹街谷）、遠景天際線、
## 移軸景深後製、暈影、氛圍（霾/雨/霓虹光池）。
## 固定俯角相機與主角由外部組裝（見 test/Hd2dProto.gd）。
## 美術鐵則：一律重用既有半寫實厚塗素材，立板 UNSHADED 保畫風，不得改畫風。
## 建築＝去背單棟厚塗立板 hd2d_bldg_01..06（透明背景，街谷可露天空/霧、有真層次）。

const TEX_DIR := "res://assets/3d/environments/ximen/"

# 去背單棟建築＋各自特徵高度（高樓 vs 矮店家），天際線才有起伏。
const BLDG_SET := [
	{"file": "hd2d_bldg_01.png", "h": 15.0},   # KTV/卡拉OK 綜合樓
	{"file": "hd2d_bldg_02.png", "h": 21.0},   # 台北光電 高塔（teal）
	{"file": "hd2d_bldg_03.png", "h": 9.0},    # 海產熱炒 矮店家（orange）
	{"file": "hd2d_bldg_04.png", "h": 14.0},   # 卡拉OK·酒店（magenta）
	{"file": "hd2d_bldg_05.png", "h": 17.0},   # 藥局診所 鉛筆樓（green）
	{"file": "hd2d_bldg_06.png", "h": 11.0},   # 麻將茶藝館 轉角樓（purple）
]

# 街道沿 -Z 縱深延伸；玩家在 z≈0，相機在 +Z 高處俯看 -Z（箱庭縱深）。
const STREET_LEN := 48.0       # 地面長度（Z）
const STREET_W := 13.0         # 地面寬度（X）（窄＝街道感，非廣場）
const CANYON_HALF_W := 5.5     # 街谷半寬：建築立面線離街心的 X
const ROWS_PER_SIDE := 6       # 每側遞遠的立板層數
const ROW_FRONT_Z := 1.0       # 最前一棟（在相機前框景、不擋主角）
const ROW_DZ := 5.6            # 層距（沿 -Z）

var _bldgs: Array = []         # [{tex: Texture2D, h: float}]
var _ground_tex: Texture2D
var _lantern_tex: Texture2D

func _ready() -> void:
	for b in BLDG_SET:
		var t := _load(TEX_DIR + b["file"])
		if t: _bldgs.append({"tex": t, "h": b["h"]})
	_ground_tex = _load(TEX_DIR + "ground_wet.png")
	_lantern_tex = _load(TEX_DIR + "hd2d_lanterns.png")
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_lanterns()
	_build_backdrop()
	_apply_cinematic()
	_build_vignette()
	_build_atmosphere()

func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# ── 基礎環境：暖夜霓虹、FILMIC tonemap、glow ──
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.085)       # 深暖夜（非死黑）＝建築間露出的天空
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.58)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC      # 避開 ACES 把霓虹去飽和成白
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0                           # 霓虹自亮跳出來成 bloom
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 0.7)
	env.set("glow_levels/5", 0.4)

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.7, 0.74, 1.0)
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = false
	add_child(sun)

# ── 地面：無縫濕柏油平面，roughness 低吃霓虹反射，含碰撞讓主角站得住 ──
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(STREET_W, STREET_LEN)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_tex
	mat.albedo_color = Color(1.25, 1.25, 1.45)
	mat.uv1_scale = Vector3(STREET_W / 5.0, STREET_LEN / 5.0, 1)
	mat.metallic = 0.0
	mat.roughness = 0.28
	mat.metallic_specular = 0.6
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(STREET_W + 8.0, 1.0, STREET_LEN + 8.0)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)

# ── 建築：遞遠霓虹街谷（每側用全套 6 棟洗牌、沿 -Z 遞遠、越遠越暗）──
# 去背單棟立板面向相機（畫本身已含 3/4 透視，不再額外 yaw）；建築間露天空/霧＝真層次。
func _build_buildings() -> void:
	if _bldgs.is_empty():
		return
	var parent := Node3D.new()
	parent.name = "Buildings"
	add_child(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260618

	for side: float in [-1.0, 1.0]:
		var order := range(_bldgs.size())
		_shuffle(order, rng)
		for i in ROWS_PER_SIDE:
			var b: Dictionary = _bldgs[order[i % order.size()]]
			var z := ROW_FRONT_Z - ROW_DZ * i
			var h: float = float(b["h"]) + rng.randf_range(-1.2, 1.2)
			var dim := clampf(1.2 - i * 0.11, 0.62, 1.2)     # 近樓提亮(>1 HDR 讓霓虹更跳)、越遠越暗＝大氣透視
			var x := side * (CANYON_HALF_W + rng.randf_range(-0.2, 0.9))
			_add_plate(parent, b["tex"], Vector3(x, h * 0.5, z), h, dim)

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]; arr[i] = arr[j]; arr[j] = t

# ── 紅燈籠串：橫掛街谷上方＝夜市氣味＋前景框景（近串被 DOF 柔化）。──
func _build_lanterns() -> void:
	if _lantern_tex == null:
		return
	var parent := Node3D.new()
	parent.name = "Lanterns"
	add_child(parent)
	var aspect := float(_lantern_tex.get_width()) / float(_lantern_tex.get_height())
	for z in [0.0, -9.0, -18.0]:
		var w := STREET_W
		var q := QuadMesh.new()
		q.size = Vector2(w, w / aspect)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = _lantern_tex
		m.albedo_color = Color(1.3, 1.3, 1.3)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		q.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = Vector3(0, 6.0, z)
		parent.add_child(mi)

# 單張去背立板：直立 QuadMesh、UNSHADED、alpha scissor（硬邊去背免排序）；dim<1 壓暗（遠景）。
func _add_plate(parent: Node3D, tex: Texture2D, pos: Vector3, height: float, dim: float) -> void:
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var q := QuadMesh.new()
	q.size = Vector2(height * aspect, height)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(dim, dim, dim)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR   # 寫深度、互相正確遮擋、免透明排序閃爍
	m.alpha_scissor_threshold = 0.5
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	parent.add_child(mi)

# ── 遠景天際線：街盡頭幾棟壓很暗的去背建築疊出遠方燈海剪影（填掉黑洞）。──
func _build_backdrop() -> void:
	if _bldgs.is_empty():
		push_warning("Hd2dStreet: _build_backdrop skipped — no _bldgs loaded")
		return
	var parent := Node3D.new()
	parent.name = "Backdrop"
	add_child(parent)
	var end_z := ROW_FRONT_Z - ROW_DZ * ROWS_PER_SIDE - 5.0
	var xs := [-6.0, -2.0, 2.0, 6.0]
	for k in xs.size():
		var b: Dictionary = _bldgs[k % _bldgs.size()]
		var h: float = float(b["h"]) + 4.0
		_add_plate(parent, b["tex"], Vector3(xs[k], h * 0.5, end_z - (k % 2) * 3.0), h, 0.4)

# ── 移軸景深（tilt-shift 微縮）：焦平面鎖主角附近，前後柔焦＝箱庭微縮感。──
# Godot 4.5 的 DOF 在 CameraAttributesPractical，透過 WorldEnvironment.camera_attributes 掛。
func _apply_cinematic() -> void:
	var we := _world_env()
	if we == null:
		return
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 13.0
	ca.dof_blur_far_transition = 5.0
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 6.0
	ca.dof_blur_near_transition = 3.0
	ca.dof_blur_amount = 0.18
	we.camera_attributes = ca

func _world_env() -> WorldEnvironment:
	for c in get_children():
		if c is WorldEnvironment:
			return c
	return null

# ── 暈影：全螢幕 ColorRect 徑向暗角 shader（Environment 無內建 vignette）。──
func _build_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.name = "VignetteLayer"
	cl.layer = 50
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" + \
		"uniform float strength = 0.6;\n" + \
		"uniform float radius = 0.78;\n" + \
		"void fragment() {\n" + \
		"	float d = distance(SCREEN_UV, vec2(0.5));\n" + \
		"	float v = smoothstep(radius, radius - 0.5, d);\n" + \
		"	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - v) * strength);\n" + \
		"}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	cl.add_child(rect)
	add_child(cl)

# ── 氛圍：遠景霾（大氣透視推縱深）＋霓虹 omni 光池（打濕地面成光暈）＋雨。──
func _build_atmosphere() -> void:
	var atmo := Node3D.new()
	atmo.name = "Atmosphere"
	add_child(atmo)

	var we := _world_env()
	if we:
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.16, 0.18, 0.34)
		we.environment.fog_density = 0.015
		we.environment.fog_aerial_perspective = 0.3
		we.environment.fog_sky_affect = 0.0

	var cols := [Color(1.0, 0.4, 0.7), Color(0.35, 0.8, 1.0), Color(1.0, 0.65, 0.35), Color(0.6, 0.45, 1.0)]
	var i := 0
	for z in [2.0, -6.0, -14.0, -22.0]:
		for side in [-1.0, 1.0]:
			var omni := OmniLight3D.new()
			omni.light_color = cols[i % cols.size()]
			omni.light_energy = 2.4
			omni.omni_range = 8.0
			omni.position = Vector3(side * (CANYON_HALF_W - 1.2), 2.4, z)
			atmo.add_child(omni)
			i += 1

	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 500
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-STREET_W, -2, -STREET_LEN), Vector3(STREET_W * 2, 30, STREET_LEN * 2))
	p.position = Vector3(0, 16, -8)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 1.5
	pm.gravity = Vector3(0, -40, 0)
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(STREET_W * 0.5, 1, STREET_LEN * 0.5)
	p.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.016, 0.45)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.6, 0.68, 0.82, 0.12)
	streak.material = rm
	p.draw_pass_1 = streak
	atmo.add_child(p)
