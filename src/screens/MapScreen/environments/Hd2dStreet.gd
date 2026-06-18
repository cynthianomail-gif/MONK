extends Node3D
## HD-2D 西門街世界建構器（八方旅人式）：厚塗 2D 立板擺進真 3D 景深。
## 本節點只建「世界」：環境、地面、建築立板、遠景背板、後製、氛圍。
## 固定俯角相機與主角由外部組裝（見 test/Hd2dProto.gd）。
## 美術鐵則：一律重用既有半寫實厚塗素材，立板 UNSHADED 保畫風，不得改畫風。
## 可獨立放進原型場景，日後整段塞進 MapScreen 的 SubViewport。

const TEX_DIR := "res://assets/3d/environments/ximen/"

# 街道沿 -Z 縱深延伸；玩家在 z≈0，相機在 +Z 高處俯看 -Z（箱庭縱深）。
const STREET_LEN := 40.0      # 地面長度（Z）
const STREET_W := 16.0        # 地面寬度（X）
const FAR_ROW_Z := -22.0      # 遠景建築排（壓暗）
const NEAR_ROW_Z := -9.0      # 近景建築排（街兩側）
const NEAR_SIDE_X := 7.0      # 近排建築離街心的 X

var _bldgs: Array = []        # 整棟厚塗建築立板貼圖 bldg_01..12
var _ground_tex: Texture2D

func _ready() -> void:
	for i in range(1, 13):
		var t := _load(TEX_DIR + "bldg_%02d.png" % i)
		if t: _bldgs.append(t)
	_ground_tex = _load(TEX_DIR + "ground_wet.png")
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_backdrop()
	# 後製＝Task 5；氛圍＝Task 6

func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# ── 基礎環境：暖夜霓虹、FILMIC tonemap、glow（後製細調在 Task 5）──
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.10)        # 深暖夜（非死黑）
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC      # 避開 ACES 把霓虹去飽和成白
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.25                          # 抬高閾值，避免 bloom floor 抬白

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# 柔和主光（立板 UNSHADED 不吃光，主要照地面與日後 lit 元件）
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.8, 0.82, 1.0)
	sun.light_energy = 0.45
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = false
	add_child(sun)

# ── 地面：無縫濕柏油平面，roughness 0.34 吃霓虹反射，含碰撞讓主角站得住 ──
func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(STREET_W, STREET_LEN)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_tex
	mat.albedo_color = Color(1.4, 1.4, 1.55)               # >1 提亮過暗柏油，霓虹光暈鋪得開
	mat.uv1_scale = Vector3(STREET_W / 3.2, STREET_LEN / 3.2, 1)
	mat.metallic = 0.0
	mat.roughness = 0.34                                    # 濕亮但非全鏡面
	mat.metallic_specular = 0.5
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	add_child(mi)

	# 地面碰撞（單一平面盒）
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(STREET_W + 8.0, 1.0, STREET_LEN + 8.0)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)

# ── 建築景深層：近排（街兩側）＋遠排（壓暗）＝箱庭縱深。──
# 立板＝直立 QuadMesh，法線朝 +Z（面向相機），UNSHADED 保厚塗畫風，
# 整張矩形（原型先不去背）。高度隨機、寬度依貼圖比例避免拉伸。
func _build_buildings() -> void:
	if _bldgs.is_empty():
		return
	var parent := Node3D.new()
	parent.name = "Buildings"
	add_child(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260618

	# 遠排：橫跨 X 的一道燈海樓牆，壓暗讀成遠景
	var far_x := -STREET_W * 0.5
	while far_x <= STREET_W * 0.5:
		var h := rng.randf_range(13.0, 18.0)
		_add_plate(parent, _bldgs[rng.randi() % _bldgs.size()],
			Vector3(far_x, h * 0.5, FAR_ROW_Z), h, 0.6)
		far_x += rng.randf_range(6.0, 8.0)

	# 近排：左右各擺幾棟，中央留街給主角走（|x| < ~4 不放）
	for side in [-1.0, 1.0]:
		var n := rng.randi_range(2, 3)
		for i in n:
			var h2 := rng.randf_range(9.0, 15.0)
			var z := NEAR_ROW_Z + rng.randf_range(-5.0, 5.0)
			var x: float = side * (NEAR_SIDE_X + rng.randf_range(-0.6, 1.6))
			_add_plate(parent, _bldgs[rng.randi() % _bldgs.size()],
				Vector3(x, h2 * 0.5, z), h2, 1.0)

# 單張立板：直立 QuadMesh、面向 +Z、UNSHADED；dim<1 壓暗（遠景）。
func _add_plate(parent: Node3D, tex: Texture2D, pos: Vector3, height: float, dim: float) -> void:
	var aspect := float(tex.get_width()) / float(tex.get_height())   # 768/1376≈0.558
	var q := QuadMesh.new()
	q.size = Vector2(height * aspect, height)                        # QuadMesh 預設立在 XY 平面、法線 +Z
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(dim, dim, dim)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	parent.add_child(mi)

# ── 遠景背板：街盡頭一片壓暗燈海，填掉黑洞、讓街像繼續延伸。──
func _build_backdrop() -> void:
	if _bldgs.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(STREET_W * 2.5, 26.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _bldgs[_bldgs.size() - 1]
	m.albedo_color = Color(0.4, 0.4, 0.5)            # 壓暗＝遠景
	m.uv1_scale = Vector3(4, 2, 1)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	mi.mesh = q
	mi.position = Vector3(0, 11.0, FAR_ROW_Z - 8.0)
	add_child(mi)
