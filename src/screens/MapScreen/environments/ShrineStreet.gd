extends Node3D
## 程式化「彩色神社街」環境（幾何盒體＋stylized 程序材質，不貼 AI 圖）。
## 2026-07-02 色彩全開＋去水墨：拿掉筆刷 toon 色階/螢幕描邊/和紙紋（使用者拍板），
## 改標準光照＋法線凹凸的 stylized shader（圓石板路/瓦屋頂/細膩白壁）——
## 真天空(ProceduralSky 四時段)、白壁/藍瓦/朱紅的飽和色票、櫻花樹+花瓣粒子、
## 卡通雲、花盆花草；霧只做遠淡不再封天。
## 版型＝L 形：主街(沿 -Z)＋西側支街(沿 -X，於 JUNC_Z 轉彎)，讓探索不是一直線。
## 全區用隱形碰撞牆圍住邊界（照 L 外框），玩家走不出街道＝不會晃進空曠虛空。
## _ready 動態建：env/光、L 形石板地面(含碰撞)、邊界牆、兩街店家、燈籠、鳥居、遠景、道具。
## shader 來源＝assets/shaders/stylized/*.gdshader。

const PLASTER_SHADER := preload("res://assets/shaders/stylized/plaster.gdshader")
const COBBLE_SHADER := preload("res://assets/shaders/stylized/cobblestone.gdshader")
const ROOF_SHADER := preload("res://assets/shaders/stylized/roof_tiles.gdshader")

# ── L 形版型參數（NPC/敵人座標依這些擺；改版型記得同步 map_npcs.json / map_enemies.json）──
const MAIN_HALF_W := 5.5      # 主街可走半寬；牆在 x=±5.5
const MAIN_BUILD_X := 8.0     # 主街店家中心 X
const SOUTH_Z := 8.0          # 主街入口牆（玩家 spawn z=6 在牆內）
const NORTH_Z := -28.0        # 主街盡頭（鳥居＋神社）
const JUNC_Z := -13.0         # 支街中心 Z（轉彎口）
const SIDE_HALF_D := 5.0      # 支街可走半深；牆在 z=JUNC_Z±5 = [-18,-8]
const SIDE_BUILD_OFF := 7.5   # 支街店家離街心的 Z 偏移
const WEST_X := -30.0         # 支街西端牆
const WALL_H := 5.0

# 牆面（彩色化：白壁漆喰/木紋/藍灰）；樑柱細件用暖深木色（去水墨後近黑會死黑，改木棕）
var _inks := [Color(0.95, 0.92, 0.86), Color(0.80, 0.66, 0.48), Color(0.68, 0.74, 0.85)]
var _accents := [Color(0.80, 0.24, 0.16), Color(0.28, 0.54, 0.38), Color(0.88, 0.68, 0.24)]
var _norens := [Color(0.20, 0.30, 0.62), Color(0.78, 0.20, 0.15), Color(0.18, 0.48, 0.46)]
const ROOF_TILE := Color(0.28, 0.36, 0.54)     # 藍瓦(主屋頂)
const ROOF_AWNING := Color(0.24, 0.30, 0.44)   # 店面雨庇
const WOOD_DARK := Color(0.27, 0.20, 0.15)     # 樑柱/格子/招牌桿
const WOOD_MID := Color(0.42, 0.31, 0.21)      # 欄杆/框

# ── 時段光照（0上午/1下午/2傍晚/3深夜）────────────────────
# 深夜＝藍墨夜、燈籠變主光源；傍晚＝橘霞低陽。lantern_mult 乘在暖光/發光體的基準能量上。
# sky_top/sky_hor 驅動 ProceduralSky；cloud_col 染卡通雲；sat 每時段飽和度；
# 霧密度全面調淡＋fog_sky_affect 壓低＝霧只做遠景空氣感，不再把天空糊掉。
const ROOF_PALETTE := [
	Color(0.22, 0.29, 0.43),
	Color(0.30, 0.32, 0.36),
	Color(0.22, 0.38, 0.36),
]

const TIME_PROFILES := [
	{ "sun_rot": Vector3(-42, -38, 0), "sun_col": Color(1.0, 0.96, 0.86), "sun_e": 1.00,
	  "sky_top": Color(0.22, 0.46, 0.86), "sky_hor": Color(0.74, 0.86, 0.96),
	  "amb_col": Color(0.72, 0.78, 0.88), "amb_e": 0.58, "sat": 1.04,
	  "fog_col": Color(0.86, 0.90, 0.96), "fog_d": 0.001,
	  "cloud_col": Color(1.0, 1.0, 1.0), "lantern_mult": 0.3, "glow": 0.5 },   # 白天燈籠/障子幾乎不發光
	{ "sun_rot": Vector3(-30, 48, 0), "sun_col": Color(1.0, 0.90, 0.72), "sun_e": 0.98,
	  "sky_top": Color(0.25, 0.48, 0.84), "sky_hor": Color(0.88, 0.88, 0.80),
	  "amb_col": Color(0.80, 0.78, 0.72), "amb_e": 0.54, "sat": 1.04,
	  "fog_col": Color(0.90, 0.88, 0.80), "fog_d": 0.0012,
	  "cloud_col": Color(1.0, 0.97, 0.90), "lantern_mult": 0.45, "glow": 0.5 },
	{ "sun_rot": Vector3(-13, 62, 0), "sun_col": Color(1.0, 0.52, 0.28), "sun_e": 0.9,
	  "sky_top": Color(0.36, 0.26, 0.52), "sky_hor": Color(0.98, 0.56, 0.34),
	  "amb_col": Color(0.68, 0.50, 0.52), "amb_e": 0.38, "sat": 1.10,
	  "fog_col": Color(0.88, 0.56, 0.42), "fog_d": 0.0022,
	  "cloud_col": Color(1.0, 0.70, 0.58), "lantern_mult": 1.6, "glow": 0.65 },
	{ "sun_rot": Vector3(-58, 25, 0), "sun_col": Color(0.55, 0.65, 0.95), "sun_e": 0.28,
	  "sky_top": Color(0.03, 0.05, 0.12), "sky_hor": Color(0.10, 0.14, 0.26),
	  "amb_col": Color(0.26, 0.30, 0.44), "amb_e": 0.30, "sat": 1.0,
	  "fog_col": Color(0.08, 0.10, 0.16), "fog_d": 0.0035,
	  "cloud_col": Color(0.28, 0.32, 0.44), "lantern_mult": 2.4, "glow": 0.85 },
]

var _env: Environment = null
var _sun: DirectionalLight3D = null
var _sky_mat: ProceduralSkyMaterial = null
var _cloud_mats: Array = []    # StandardMaterial3D 卡通雲，時段染色
var _warm_lights: Array = []   # [OmniLight3D, base_energy] 燈籠/石燈籠暖光
var _warm_mats: Array = []     # [StandardMaterial3D, base_emission] 發光體(燈球/火袋/店內光)

# 時段環境音景（day 蟬鳴共用上/下午、dusk 暮蟬+烏鴉、night 蟲鳴），走 SFX bus 吃設定音量。
const AMBIENT_BY_PERIOD := ["day", "day", "dusk", "night"]
var _ambient: AudioStreamPlayer = null

func _ready() -> void:
	add_to_group("minimap_streets")
	_build_env(self)
	_build_ground(self)
	_build_boundaries(self)
	_build_shops(self)
	_build_minigame_signs(self)
	_build_torii(self)
	_build_shrine_architecture(self)
	_build_lanterns(self)
	_build_stone_lanterns(self)
	_build_backdrop(self)
	_build_props(self)
	_build_sakura(self)
	_build_flowers(self)
	_build_clouds(self)
	_build_falling_leaves(self)
	_fix_player_deferred()
	_apply_time_profile(int(GameManager.player.get("period", 0)))
	GameManager.time_advanced.connect(_apply_time_profile)
	if OS.is_debug_build():
		print("SHRINE_STREET ready")

## 依時段套光照 profile（time_advanced 直接接這裡；時段切換都發生在選單/轉場後，直接套不做過渡）。
func _apply_time_profile(period: int) -> void:
	var p: Dictionary = TIME_PROFILES[clampi(period, 0, TIME_PROFILES.size() - 1)]
	if _env != null:
		_env.ambient_light_color = p.amb_col
		_env.ambient_light_energy = p.amb_e
		_env.fog_light_color = p.fog_col
		_env.fog_density = p.fog_d
		_env.glow_intensity = p.glow
		_env.adjustment_saturation = p.sat
	if _sky_mat != null:
		_sky_mat.sky_top_color = p.sky_top
		_sky_mat.sky_horizon_color = p.sky_hor
		_sky_mat.ground_horizon_color = p.sky_hor
		_sky_mat.ground_bottom_color = p.sky_hor.darkened(0.35)
	for cm in _cloud_mats:
		(cm as StandardMaterial3D).albedo_color = p.cloud_col
	if _sun != null:
		_sun.rotation_degrees = p.sun_rot
		_sun.light_color = p.sun_col
		_sun.light_energy = p.sun_e
	for entry in _warm_lights:
		(entry[0] as OmniLight3D).light_energy = entry[1] * p.lantern_mult
	for entry in _warm_mats:
		(entry[0] as StandardMaterial3D).emission_energy_multiplier = entry[1] * p.lantern_mult
	_apply_ambient(period)

## 時段環境音：換到不同 loop 才重播（上/下午共用 day 不中斷）。音檔缺就靜默跳過。
func _apply_ambient(period: int) -> void:
	var key: String = AMBIENT_BY_PERIOD[clampi(period, 0, AMBIENT_BY_PERIOD.size() - 1)]
	var path := "res://assets/audio/ambient/ambient_%s.ogg" % key
	if not ResourceLoader.exists(path):
		return
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		_ambient.bus = "SFX"
		_ambient.volume_db = -10.0
		add_child(_ambient)
	var stream := load(path) as AudioStream
	if _ambient.stream == stream and _ambient.playing:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambient.stream = stream
	_ambient.play()

## 小地圖街道帶（世界 XZ；Rect2.position=(西,北) size=(寬,深)）＝L 形可走範圍。
func minimap_streets() -> Array:
	return [
		Rect2(-MAIN_HALF_W, NORTH_Z, MAIN_HALF_W * 2.0, SOUTH_Z - NORTH_Z),
		Rect2(WEST_X, JUNC_Z - SIDE_HALF_D, -MAIN_HALF_W - WEST_X, SIDE_HALF_D * 2.0),
	]

## 落葉粒子：沿用 minimap_streets() 的兩段 L 形街道範圍當飄落區，顏色取 _accents(楓紅/苔綠/枯金)
## 呼應店家配色。不貼圖，unshaded billboard quad＋hue_variation 做顏色差異＋turbulence 做飄蕩感。
func _build_falling_leaves(root: Node3D) -> void:
	for zone in minimap_streets():
		var r: Rect2 = zone
		var cx := r.position.x + r.size.x * 0.5
		var cz := r.position.y + r.size.y * 0.5
		var p := GPUParticles3D.new()
		p.name = "FallingLeaves"
		p.amount = 90
		p.lifetime = 7.0
		p.position = Vector3(cx, 6.0, cz)   # 壓低發射高度，別讓紅葉飄在天空背景變雜點
		p.visibility_aabb = AABB(
			Vector3(-r.size.x * 0.5 - 2.0, -10.0, -r.size.y * 0.5 - 2.0),
			Vector3(r.size.x + 4.0, 20.0, r.size.y + 4.0)
		)
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 25.0
		pm.gravity = Vector3(0, -0.55, 0)
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.9
		pm.angular_velocity_min = -90.0
		pm.angular_velocity_max = 90.0
		pm.hue_variation_min = -0.08
		pm.hue_variation_max = 0.08
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(r.size.x * 0.5, 0.4, r.size.y * 0.5)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_noise_scale = 2.0
		pm.turbulence_noise_speed = Vector3(0.1, 0.05, 0.1)
		p.process_material = pm
		var leaf := QuadMesh.new()
		leaf.size = Vector2(0.14, 0.14)
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# 只用楓紅/枯金/櫻粉——綠葉quad飄在天空背景會像綠色雜點
		var leaf_cols: Array = [_accents[0], _accents[2], Color(0.96, 0.72, 0.80), Color(0.93, 0.58, 0.70)]
		lm.albedo_color = leaf_cols[randi() % leaf_cols.size()]
		leaf.material = lm
		p.draw_pass_1 = leaf
		root.add_child(p)

# ── 玩家材質修正：延幀等玩家進場（CameraRig/Player 在自己的 _ready 才就位）──
func _fix_player_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_fix_figure_materials(player)
		if OS.is_debug_build():
			print("SHRINE_PLAYER_MAT ok")

## 玩家材質：保留 Meshy 貼圖＋修透明雷（base-color alpha 會把整模型變透明），消光防塑膠感。
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

# ── 材質 / 幾何 helper ──────────────────────────────────
## 通用面材：細膩牆面(streak=0)或木紋(streak>0)。
func _flat_mat(color: Color, streak: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLASTER_SHADER
	m.set_shader_parameter("albedo", color)
	if streak > 0.0:
		m.set_shader_parameter("streak", streak)
		m.set_shader_parameter("rough", 0.85)
	return m

func _roof_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROOF_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = COBBLE_SHADER
	m.set_shader_parameter("albedo", Color(0.69, 0.66, 0.60))   # 亮暖石，配彩色街景
	m.set_shader_parameter("stone_size", 0.38)
	m.set_shader_parameter("bump", 0.28)
	m.set_shader_parameter("mortar_darken", 0.48)
	m.set_shader_parameter("rough_stone", 0.80)   # 乾石無光澤（低粗糙會變拋光蛋）
	return m

func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	root.add_child(mi)
	return mi

## tiles=true 上瓦片材質（店家屋頂/雨庇）；false 素面（遠山、石燈籠帽等非瓦件）。
func _roof(root: Node3D, pos: Vector3, size: Vector3, color: Color, tiles: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = _roof_mat(color) if tiles else _flat_mat(color)
	root.add_child(mi)

## 障子紙窗面板：微暖光、入 _warm_mats → 夜裡二樓窗透光。
func _shoji(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.88, 0.78)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.80, 0.46)
	m.emission_energy_multiplier = 0.55
	mi.material_override = m
	root.add_child(mi)
	_warm_mats.append([m, 0.55])

## 暖光發光店內面板（thin 板）。
func _lit(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var lit := MeshInstance3D.new()
	var lq := BoxMesh.new()
	lq.size = size
	lit.mesh = lq
	lit.position = pos
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.78, 0.46)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.72, 0.38)
	lm.emission_energy_multiplier = 0.9
	lit.material_override = lm
	root.add_child(lit)
	_warm_mats.append([lm, 0.9])

# ── 環境 ────────────────────────────────────────────────
func _build_env(root: Node3D) -> void:
	_env = Environment.new()
	# 真天空：ProceduralSky（太陽圓盤跟 DirectionalLight 方向走），顏色由時段 profile 驅動
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 20.0
	_sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.72, 0.78, 0.88)
	_env.ambient_light_energy = 0.50
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.02
	_env.glow_hdr_threshold = 1.8   # 彩色化後牆面變亮，1.3 會把白牆/櫻花炸成光球
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.86, 0.90, 0.96)
	_env.fog_density = 0.001
	_env.fog_sky_affect = 0.12   # 霧幾乎不糊天空（不然天又被蓋回紙色）
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.12
	_env.adjustment_contrast = 1.06   # 彩色化後對比降一點，避免噪點/陰影斑被放大
	_env.ssao_enabled = true
	_env.ssao_radius = 1.6
	_env.ssao_intensity = 2.2
	var we := WorldEnvironment.new()
	we.environment = _env
	root.add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42, -38, 0)
	_sun.light_color = Color(1.0, 0.93, 0.80)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	# 亮牆會把 shadow acne（斑點狀陰影雜訊）放大成豹紋，加大 normal bias＋縮短陰影距離提精度
	_sun.shadow_normal_bias = 4.0
	_sun.directional_shadow_max_distance = 70.0
	_sun.shadow_blur = 2.0   # 柔和陰影邊（去 toon 後硬影會顯得 CG）
	root.add_child(_sun)

# ── L 形地面（主 + 側 兩塊，含碰撞）───────────────────────
## 2026-07-08 邊界破綻修正：主街地面北緣原本只到 z=-30，但神社本殿平台中心在
## z≈-35.5（NORTH_Z-7.5），平台實際落在地面網格外——從轉彎口等角度側看會看見
## 平台底部與虛空天空間的縫隙。北緣延伸到 z=-46 完整包住本殿平台＋背景杉林。
func _build_ground(root: Node3D) -> void:
	_ground_slab(root, Vector3(0, -0.1, -18.0), Vector3(16, 0.2, 56))          # 主街 x[-8,8] z[-46,10]
	_ground_slab(root, Vector3(-18.5, -0.1, JUNC_Z), Vector3(25, 0.2, 12))     # 側街 x[-31,-6] z[-19,-7]
	_build_ground_skirt(root)

## 遠景「圍裙」地面：一片遠比可走範圍大、貼地略低於主地面的純視覺(無碰撞)平面，
## 蓋住主街/支街地面網格邊緣以外的所有方向。純色配地面材質基調，配合霧把接縫
## 藏進霧裡——不新增碰撞、不影響既有邊界牆/相機遮擋，最小改動堵住任意角度側看
## /回頭看時「地板邊緣外的虛空」破綻（南口回頭看、東西側看皆會露這塊）。
func _build_ground_skirt(root: Node3D) -> void:
	var skirt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)   # 遠超霧視距(即使 fog_density 最低 0.001 也在數百米內糊掉)，接縫不會露餡
	skirt.mesh = pm
	skirt.position = Vector3(-10.0, -0.35, -10.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.50, 0.48, 0.42)   # 略暗於主石板色，遠景霧會再壓一層，避免跟主地面搶戲
	m.roughness = 0.95
	skirt.material_override = m
	root.add_child(skirt)

func _ground_slab(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = size
	ground.mesh = gb
	ground.position = pos
	ground.material_override = _ground_mat()
	root.add_child(ground)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	root.add_child(body)

# ── 邊界隱形碰撞牆（照 L 外框 8 段）──────────────────────
func _build_boundaries(root: Node3D) -> void:
	var cz := (SOUTH_Z + NORTH_Z) * 0.5
	var clen := SOUTH_Z - NORTH_Z
	_wall(root, Vector3(MAIN_HALF_W, WALL_H * 0.5, cz), Vector3(0.4, WALL_H, clen))          # 東牆(主街右)
	_wall(root, Vector3(0, WALL_H * 0.5, SOUTH_Z), Vector3(MAIN_HALF_W * 2, WALL_H, 0.4))    # 南口
	_wall(root, Vector3(0, WALL_H * 0.5, NORTH_Z), Vector3(MAIN_HALF_W * 2, WALL_H, 0.4))    # 北端
	# 主街左牆（被支街開口切成上下兩段：開口 z∈[-18,-8]）
	var south_len := SOUTH_Z - (JUNC_Z + SIDE_HALF_D)
	_wall(root, Vector3(-MAIN_HALF_W, WALL_H * 0.5, (SOUTH_Z + JUNC_Z + SIDE_HALF_D) * 0.5), Vector3(0.4, WALL_H, south_len))
	var north_len := (JUNC_Z - SIDE_HALF_D) - NORTH_Z
	_wall(root, Vector3(-MAIN_HALF_W, WALL_H * 0.5, ((JUNC_Z - SIDE_HALF_D) + NORTH_Z) * 0.5), Vector3(0.4, WALL_H, north_len))
	# 支街 上/下 長牆 + 西端
	var side_cx := (WEST_X - MAIN_HALF_W) * 0.5
	var side_len := (-MAIN_HALF_W) - WEST_X
	_wall(root, Vector3(side_cx, WALL_H * 0.5, JUNC_Z + SIDE_HALF_D), Vector3(side_len, WALL_H, 0.4))  # 支街南牆
	_wall(root, Vector3(side_cx, WALL_H * 0.5, JUNC_Z - SIDE_HALF_D), Vector3(side_len, WALL_H, 0.4))  # 支街北牆
	_wall(root, Vector3(WEST_X, WALL_H * 0.5, JUNC_Z), Vector3(0.4, WALL_H, SIDE_HALF_D * 2))          # 西端

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

func _wall(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	root.add_child(body)

# ── 店家（主街沿 Z + 支街沿 X）────────────────────────────
func _build_shops(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var i := 0
	# 主街：z 由南到北，兩側；左側在支街開口 z∈[-18,-8] 留空當轉彎口
	var z := SOUTH_Z - 2.0
	while z > NORTH_Z:
		_shop_x(root, MAIN_BUILD_X, z, 1, i, rng); i += 1
		if not (z < (JUNC_Z + SIDE_HALF_D + 0.5) and z > (JUNC_Z - SIDE_HALF_D - 0.5)):
			_shop_x(root, -MAIN_BUILD_X, z, -1, i, rng); i += 1
		z -= rng.randf_range(7.0, 9.0)
	# 支街：x 由東到西，兩側（南 z=JUNC_Z+off / 北 z=JUNC_Z-off）
	var xx := -11.0
	while xx > WEST_X + 2.0:
		_shop_z(root, xx, JUNC_Z + SIDE_BUILD_OFF, 1, i, rng); i += 1
		_shop_z(root, xx, JUNC_Z - SIDE_BUILD_OFF, -1, i, rng); i += 1
		xx -= rng.randf_range(7.0, 9.0)

## 主街店家：建在 x=side*MAIN_BUILD_X，店面朝 -side*X（街心）。沿街寬度在 Z。
func _shop_x(root: Node3D, x: float, z: float, side: int, i: int, rng: RandomNumberGenerator) -> void:
	var shop_root := Node3D.new()
	shop_root.name = "ShrineShopX_%02d" % i
	shop_root.add_to_group("shrine_shop")
	var archetype := i % 3
	shop_root.set_meta("archetype", archetype)
	root.add_child(shop_root)
	var hgt := rng.randf_range(3.5, 6.5)
	var w := rng.randf_range(4.0, 6.0)
	var d := rng.randf_range(4.5, 6.5)
	_box(shop_root, Vector3(x, hgt * 0.5, z), Vector3(w, hgt, d), _inks[i % _inks.size()])
	var roof_h := rng.randf_range(1.6, 2.6)
	var roof_col: Color = ROOF_PALETTE[archetype]
	_roof(shop_root, Vector3(x, hgt + roof_h * 0.5, z), Vector3(w + 1.4, roof_h, d + 1.4), roof_col)
	_cam_blocker(shop_root, Vector3(x, (hgt + roof_h) * 0.5, z), Vector3(w, hgt + roof_h, d))
	var fx := x - float(side) * (w * 0.5 + 0.05)
	var sh := minf(hgt, 3.0)
	_lit(shop_root, Vector3(fx, sh * 0.45, z), Vector3(0.12, sh * 0.72, d * 0.62))
	_box(shop_root, Vector3(fx - float(side) * 0.10, sh * 0.80, z), Vector3(0.08, sh * 0.32, d * 0.64), _norens[i % _norens.size()])
	_roof(shop_root, Vector3(fx - float(side) * 0.55, sh + 0.05, z), Vector3(1.3, 0.8, d * 0.95), roof_col.darkened(0.10))
	for bi in range(4):
		var bz := z - d * 0.26 + float(bi) * (d * 0.52 / 3.0)
		_box(shop_root, Vector3(fx - float(side) * 0.04, sh * 0.45, bz), Vector3(0.05, sh * 0.66, 0.05), WOOD_DARK)
	_box(shop_root, Vector3(fx - float(side) * 0.04, sh * 0.62, z), Vector3(0.05, 0.06, d * 0.58), WOOD_DARK)
	var sign_col: Color = [WOOD_MID, Color(0.30, 0.13, 0.10)][i % 2]
	_box(shop_root, Vector3(fx - float(side) * 0.52, sh - 0.25, z), Vector3(0.06, 0.55, 0.8), sign_col)
	if i % 2 == 0:
		_box(shop_root, Vector3(x, hgt + 0.4, z), Vector3(w + 1.2, 0.8, d + 1.2), _accents[i % _accents.size()])
	_facade_x(shop_root, x, z, side, w, hgt, d, i)
	_decorate_shop_x(shop_root, x, z, side, w, hgt, d, archetype)

func _decorate_shop_x(root: Node3D, x: float, z: float, side: int, w: float, hgt: float, d: float, archetype: int) -> void:
	var front_x := x - float(side) * (w * 0.5 + 0.18)
	if archetype == 0:
		for offset in [-0.34, 0.0, 0.34]:
			_box(root, Vector3(front_x, 2.15, z + offset * d), Vector3(0.08, 0.10, d * 0.18), Color(0.64, 0.46, 0.24))
	elif archetype == 1 and hgt >= 4.2:
		_box(root, Vector3(front_x - float(side) * 0.22, 3.15, z), Vector3(0.10, 0.10, d * 0.70), WOOD_MID)
		for offset in [-0.30, -0.10, 0.10, 0.30]:
			_box(root, Vector3(front_x - float(side) * 0.22, 2.92, z + offset * d), Vector3(0.08, 0.46, 0.08), WOOD_DARK)
	else:
		_box(root, Vector3(x, hgt + 1.0, z), Vector3(w + 0.8, 0.14, 0.16), Color(0.18, 0.20, 0.22))
		_box(root, Vector3(front_x - float(side) * 0.34, 2.3, z), Vector3(0.08, 1.25, 0.62), Color(0.32, 0.12, 0.10))

## 主街店家 2F 立面細節（沿街軸=Z）：木骨架角柱/腰樑＋屋簷垂木列＋格子窗(障子夜透光)＋隔棟欄杆。
func _facade_x(root: Node3D, x: float, z: float, side: int, w: float, hgt: float, d: float, i: int) -> void:
	var dark := WOOD_DARK
	# 町家木骨架：前緣兩根角柱＋(樓高才有)腰樑，白壁配深木框
	var px := x - float(side) * (w * 0.5 + 0.02)
	for pz in [z - d * 0.5 + 0.10, z + d * 0.5 - 0.10]:
		_box(root, Vector3(px, hgt * 0.5, pz), Vector3(0.16, hgt, 0.16), dark)
	if hgt >= 4.2:
		_box(root, Vector3(px, 3.45, z), Vector3(0.12, 0.16, d), dark)
	var rz := z - d * 0.5 + 0.35
	while rz < z + d * 0.5 - 0.2:
		_box(root, Vector3(x - float(side) * (w * 0.5 + 0.35), hgt - 0.08, rz), Vector3(0.72, 0.09, 0.12), dark)
		rz += 0.62
	if hgt < 4.2:
		return   # 平房只有垂木
	var fx := x - float(side) * (w * 0.5 + 0.04)
	var wy := hgt * 0.68
	var wh := minf(hgt * 0.28, 1.3)
	var ww := d * 0.52
	_box(root, Vector3(fx, wy, z), Vector3(0.07, wh + 0.18, ww + 0.18), dark)
	_shoji(root, Vector3(fx - float(side) * 0.02, wy, z), Vector3(0.05, wh, ww))
	for bi in range(5):
		var bz := z - ww * 0.5 + float(bi + 1) * (ww / 6.0)
		_box(root, Vector3(fx - float(side) * 0.06, wy, bz), Vector3(0.04, wh, 0.05), dark)
	_box(root, Vector3(fx - float(side) * 0.06, wy, z), Vector3(0.04, 0.05, ww), dark)
	if i % 2 == 1:
		var wood := WOOD_MID
		var ry := wy - wh * 0.5 - 0.28
		var rx := fx - float(side) * 0.22
		_box(root, Vector3(rx, ry, z), Vector3(0.06, 0.06, ww + 0.3), wood)
		for pi in range(5):
			var pz := z - (ww + 0.2) * 0.5 + float(pi) * ((ww + 0.2) / 4.0)
			_box(root, Vector3(rx, ry - 0.14, pz), Vector3(0.05, 0.26, 0.05), wood)

## 支街店家：建在 z=lane±off，店面朝 -side*Z（街心）。沿街寬度在 X（＝_shop_x 的 x/z 對調）。
func _shop_z(root: Node3D, x: float, z: float, side: int, i: int, rng: RandomNumberGenerator) -> void:
	var shop_root := Node3D.new()
	shop_root.name = "ShrineShopZ_%02d" % i
	shop_root.add_to_group("shrine_shop")
	var archetype := i % 3
	shop_root.set_meta("archetype", archetype)
	root.add_child(shop_root)
	var hgt := rng.randf_range(3.5, 6.5)
	var w := rng.randf_range(4.0, 6.0)   # 沿街(X)
	var d := rng.randf_range(4.5, 6.5)   # 深(Z)
	_box(shop_root, Vector3(x, hgt * 0.5, z), Vector3(w, hgt, d), _inks[i % _inks.size()])
	var roof_h := rng.randf_range(1.6, 2.6)
	var roof_col: Color = ROOF_PALETTE[archetype]
	_roof(shop_root, Vector3(x, hgt + roof_h * 0.5, z), Vector3(w + 1.4, roof_h, d + 1.4), roof_col)
	_cam_blocker(shop_root, Vector3(x, (hgt + roof_h) * 0.5, z), Vector3(w, hgt + roof_h, d))
	var fz := z - float(side) * (d * 0.5 + 0.05)
	var sh := minf(hgt, 3.0)
	_lit(shop_root, Vector3(x, sh * 0.45, fz), Vector3(w * 0.62, sh * 0.72, 0.12))
	_box(shop_root, Vector3(x, sh * 0.80, fz - float(side) * 0.10), Vector3(w * 0.64, sh * 0.32, 0.08), _norens[i % _norens.size()])
	_roof(shop_root, Vector3(x, sh + 0.05, fz - float(side) * 0.55), Vector3(w * 0.95, 0.8, 1.3), roof_col.darkened(0.10))
	for bi in range(4):
		var bx := x - w * 0.26 + float(bi) * (w * 0.52 / 3.0)
		_box(shop_root, Vector3(bx, sh * 0.45, fz - float(side) * 0.04), Vector3(0.05, sh * 0.66, 0.05), WOOD_DARK)
	var sign_col: Color = [WOOD_MID, Color(0.30, 0.13, 0.10)][i % 2]
	_box(shop_root, Vector3(x, sh - 0.25, fz - float(side) * 0.52), Vector3(0.8, 0.55, 0.06), sign_col)
	if i % 2 == 0:
		_box(shop_root, Vector3(x, hgt + 0.4, z), Vector3(w + 1.2, 0.8, d + 1.2), _accents[i % _accents.size()])
	_facade_z(shop_root, x, z, side, w, hgt, d, i)
	_decorate_shop_z(shop_root, x, z, side, w, hgt, d, archetype)

func _decorate_shop_z(root: Node3D, x: float, z: float, side: int, w: float, hgt: float, d: float, archetype: int) -> void:
	var front_z := z - float(side) * (d * 0.5 + 0.18)
	if archetype == 0:
		for offset in [-0.34, 0.0, 0.34]:
			_box(root, Vector3(x + offset * w, 2.15, front_z), Vector3(w * 0.18, 0.10, 0.08), Color(0.64, 0.46, 0.24))
	elif archetype == 1 and hgt >= 4.2:
		_box(root, Vector3(x, 3.15, front_z - float(side) * 0.22), Vector3(w * 0.70, 0.10, 0.10), WOOD_MID)
		for offset in [-0.30, -0.10, 0.10, 0.30]:
			_box(root, Vector3(x + offset * w, 2.92, front_z - float(side) * 0.22), Vector3(0.08, 0.46, 0.08), WOOD_DARK)
	else:
		_box(root, Vector3(x, hgt + 1.0, z), Vector3(0.16, 0.14, d + 0.8), Color(0.18, 0.20, 0.22))
		_box(root, Vector3(x, 2.3, front_z - float(side) * 0.34), Vector3(0.62, 1.25, 0.08), Color(0.32, 0.12, 0.10))

## 支街店家 2F 立面細節（＝_facade_x 的 x/z 對調，沿街軸=X）。
func _facade_z(root: Node3D, x: float, z: float, side: int, w: float, hgt: float, d: float, i: int) -> void:
	var dark := WOOD_DARK
	var pz := z - float(side) * (d * 0.5 + 0.02)
	for px2 in [x - w * 0.5 + 0.10, x + w * 0.5 - 0.10]:
		_box(root, Vector3(px2, hgt * 0.5, pz), Vector3(0.16, hgt, 0.16), dark)
	if hgt >= 4.2:
		_box(root, Vector3(x, 3.45, pz), Vector3(w, 0.16, 0.12), dark)
	var rx := x - w * 0.5 + 0.35
	while rx < x + w * 0.5 - 0.2:
		_box(root, Vector3(rx, hgt - 0.08, z - float(side) * (d * 0.5 + 0.35)), Vector3(0.12, 0.09, 0.72), dark)
		rx += 0.62
	if hgt < 4.2:
		return
	var fz := z - float(side) * (d * 0.5 + 0.04)
	var wy := hgt * 0.68
	var wh := minf(hgt * 0.28, 1.3)
	var ww := w * 0.52
	_box(root, Vector3(x, wy, fz), Vector3(ww + 0.18, wh + 0.18, 0.07), dark)
	_shoji(root, Vector3(x, wy, fz - float(side) * 0.02), Vector3(ww, wh, 0.05))
	for bi in range(5):
		var bx := x - ww * 0.5 + float(bi + 1) * (ww / 6.0)
		_box(root, Vector3(bx, wy, fz - float(side) * 0.06), Vector3(0.05, wh, 0.04), dark)
	_box(root, Vector3(x, wy, fz - float(side) * 0.06), Vector3(ww, 0.05, 0.04), dark)
	if i % 2 == 1:
		var wood := WOOD_MID
		var ry := wy - wh * 0.5 - 0.28
		var rzz := fz - float(side) * 0.22
		_box(root, Vector3(x, ry, rzz), Vector3(ww + 0.3, 0.06, 0.06), wood)
		for pi in range(5):
			var px := x - (ww + 0.2) * 0.5 + float(pi) * ((ww + 0.2) / 4.0)
			_box(root, Vector3(px, ry - 0.14, rzz), Vector3(0.05, 0.26, 0.05), wood)

## 地標招牌群（2026-07-03 使用者反饋「互動店家要讓玩家一眼認出」）：
## ①打擊場/保齡球館＝完整店面妝點（大橫匾+紅燈籠對+彩色暖簾），蓋在建築線牆上；
## ②佛具店/食堂＝路邊木製置き看板（立牌+直書字+頂燈籠）；
## ③賽錢箱＝實體木箱道具；④化緣點＝蒲團+缽。
## 互動點本身在 map_npcs.json，座標必須落在可走範圍內(|x|<MAIN_HALF_W)；
## 招牌/道具是純視覺可以貼牆或超出建築線。
func _build_minigame_signs(root: Node3D) -> void:
	# x=5.55＝貼街牆線。門面是自立門構え（含落地門柱），不依賴後面隨機建築的位置
	_storefront(root, 5.55, -9.0, -1, "保齡球館", Color(0.20, 0.32, 0.66))
	_storefront(root, -5.55, -21.0, 1, "打擊場", Color(0.22, 0.50, 0.30))
	_standing_sign(root, Vector3(-9.2, 0, -9.3), "佛具店")
	_standing_sign(root, Vector3(-17.4, 0, -9.3), "食堂")
	_saisen_box(root, Vector3(1.8, 0, -26.5))
	_alms_spot(root, Vector3(3.0, 0, -2.0))

## 店面妝點：橫匾(金字)+匾上小屋簷+兩側紅燈籠+底下彩色暖簾。x=建築線前緣、
## side=-1 表示店面朝 -X（東側建築），文字轉向街心。
func _storefront(root: Node3D, x: float, z: float, side: int, text: String, noren_col: Color) -> void:
	var face := float(side)
	# 落地門柱×2（自立門構え：門面有自己的支撐，不會因隨機建築位置而懸空/穿模）
	for pz in [z - 1.35, z + 1.35]:
		_box(root, Vector3(x, 1.35, float(pz)), Vector3(0.18, 2.7, 0.18), WOOD_DARK)
	# 突き出し看板：橫樑伸出街心＋垂直吊板（雙面字），沿街兩個方向都看得到全名。
	# 高度抬到雨庇(頂約3.5)之上，否則會被隨機建築的披簷擋住
	var bx := x + face * 1.05
	_box(root, Vector3(x, 3.2, z), Vector3(0.14, 1.9, 0.14), WOOD_DARK)   # 門柱間加高中柱撐樑
	_box(root, Vector3((x + bx) * 0.5, 4.30, z), Vector3(absf(bx - x) + 0.4, 0.10, 0.10), WOOD_DARK)
	_box(root, Vector3(bx, 3.82, z), Vector3(1.95, 0.78, 0.12), Color(0.16, 0.10, 0.07))
	_box(root, Vector3(bx, 4.24, z), Vector3(2.02, 0.06, 0.14), WOOD_MID)
	_box(root, Vector3(bx, 3.40, z), Vector3(2.02, 0.06, 0.14), WOOD_MID)
	for sside in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 68
		l.pixel_size = 0.006
		l.modulate = Color(1.25, 1.02, 0.50)
		l.outline_size = 10
		l.outline_modulate = Color(0.05, 0.03, 0.02, 0.95)
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.position = Vector3(bx, 3.82, z + 0.08 * float(sside))
		l.rotation_degrees.y = 0.0 if sside > 0.0 else 180.0
		root.add_child(l)
	# 兩側紅燈籠（入 _warm_lights/_warm_mats 跟時段，夜裡變店招燈）
	for dz in [-1.6, 1.6]:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.88, 0.24, 0.16)
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.36, 0.20)
		gm.emission_energy_multiplier = 1.6
		var glow := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.62
		glow.mesh = sm
		glow.position = Vector3(x + face * 0.25, 2.55, z + float(dz))
		glow.material_override = gm
		root.add_child(glow)
		_warm_mats.append([gm, 1.6])
		var ol := OmniLight3D.new()
		ol.position = glow.position + Vector3(face * 0.3, 0, 0)
		ol.light_color = Color(1.0, 0.62, 0.36)
		ol.light_energy = 0.9
		ol.omni_range = 5.0
		root.add_child(ol)
		_warm_lights.append([ol, 0.9])
	# 彩色暖簾（店身分色，垂在門口上緣）＋掛桿
	for k in range(4):
		var nz := z - 0.9 + float(k) * 0.6
		_box(root, Vector3(x + face * 0.16, 1.95, nz), Vector3(0.05, 0.85, 0.5), noren_col)
	_box(root, Vector3(x + face * 0.16, 2.42, z), Vector3(0.06, 0.1, 2.3), WOOD_DARK)

## 置き看板：木框立牌+直書店名（前後兩面，旋轉視角都讀得到）+頂上小燈籠。
func _standing_sign(root: Node3D, pos: Vector3, text: String) -> void:
	for dx in [-0.32, 0.32]:
		_box(root, pos + Vector3(float(dx), 0.85, 0), Vector3(0.07, 1.7, 0.07), WOOD_DARK)
	_box(root, pos + Vector3(0, 1.62, 0), Vector3(0.8, 0.08, 0.08), WOOD_DARK)
	_box(root, pos + Vector3(0, 0.95, 0), Vector3(0.62, 1.21, 0.04), WOOD_MID)
	_box(root, pos + Vector3(0, 0.95, 0), Vector3(0.56, 1.15, 0.06), Color(0.93, 0.89, 0.80))
	var chars := PackedStringArray()
	for ch in text:
		chars.append(ch)
	var vertical := "\n".join(chars)
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = vertical
		l.font_size = 52
		l.pixel_size = 0.005
		l.modulate = Color(0.15, 0.10, 0.08)
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.position = pos + Vector3(0, 0.95, 0.05 * float(side))
		l.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
		root.add_child(l)
	# 頂上小紅燈籠
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.88, 0.26, 0.16)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.38, 0.20)
	gm.emission_energy_multiplier = 1.3
	var glow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.36
	glow.mesh = sm
	glow.position = pos + Vector3(0, 1.88, 0)
	glow.material_override = gm
	root.add_child(glow)
	_warm_mats.append([gm, 1.3])

## 賽錢箱：木箱+頂面格柵投錢口+上方本坪鈴（鳥居前的參拜道具）。有實體碰撞
## （不能穿箱而過）；觸發半徑 2.2 比箱身大，站箱前一樣能互動。
func _saisen_box(root: Node3D, pos: Vector3) -> void:
	_wall(root, pos + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.0))
	_box(root, pos + Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.9), Color(0.38, 0.28, 0.18))
	_box(root, pos + Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 1.0), WOOD_DARK)
	for k in range(5):
		_box(root, pos + Vector3(-0.48 + float(k) * 0.24, 0.92, 0), Vector3(0.10, 0.05, 0.86), WOOD_DARK)
	_box(root, pos + Vector3(0, 0.92, 0), Vector3(1.3, 0.04, 0.08), WOOD_DARK)
	# 鈴繩+金鈴
	_box(root, pos + Vector3(0, 2.6, 0), Vector3(0.06, 1.6, 0.06), Color(0.78, 0.20, 0.16))
	var bell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.30
	bell.mesh = sm
	bell.position = pos + Vector3(0, 3.45, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.82, 0.66, 0.30)
	bm.metallic = 0.7
	bm.roughness = 0.35
	bell.material_override = bm
	root.add_child(bell)

## 化緣點：草蓆+木缽+缽中錢（乞食修行的落腳處）。
func _alms_spot(root: Node3D, pos: Vector3) -> void:
	_box(root, pos + Vector3(0, 0.015, 0), Vector3(1.4, 0.03, 1.0), Color(0.80, 0.70, 0.48))
	var bowl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.20
	cm.bottom_radius = 0.13
	cm.height = 0.16
	bowl.mesh = cm
	bowl.position = pos + Vector3(0.3, 0.11, 0.15)
	bowl.material_override = _flat_mat(Color(0.24, 0.16, 0.11))
	root.add_child(bowl)
	_box(root, pos + Vector3(0.3, 0.185, 0.15), Vector3(0.16, 0.02, 0.16), Color(0.85, 0.72, 0.35))

func _build_torii(root: Node3D) -> void:
	var red := Color(0.68, 0.10, 0.08)
	var zt := NORTH_Z + 1.5   # 主街盡頭
	for side in [-1, 1]:
		_box(root, Vector3(float(side) * 4.6, 4.6, zt), Vector3(0.56, 9.2, 0.62), red)
	_box(root, Vector3(0, 9.25, zt), Vector3(11.8, 0.55, 0.78), red)
	_box(root, Vector3(0, 8.0, zt), Vector3(9.6, 0.38, 0.62), red)
	_build_shrine_hall(root)

## Hero 地標：神社本殿精模（magnific 水墨圖→Meshy image-to-3d），鳥居後方視覺錨點。
## 缺檔優雅跳過（模型未生成時場景照常）。AABB 正規化到 HALL_H 高、貼地置中。
func _build_shrine_architecture(root: Node3D) -> void:
	var architecture := Node3D.new()
	architecture.name = "ShrineArchitecture"
	root.add_child(architecture)
	_build_side_street_endcap(architecture)
	_build_shrine_forecourt(architecture)
	_build_torii_details(architecture)
	_build_backdrop_depth(architecture)
	_build_town_details(architecture)

func _build_side_street_endcap(root: Node3D) -> void:
	var endcap := Node3D.new()
	endcap.name = "SideStreetEndcap"
	root.add_child(endcap)
	var stone := Color(0.42, 0.40, 0.35)
	var timber := Color(0.20, 0.14, 0.11)
	_box(endcap, Vector3(WEST_X + 0.28, 2.25, JUNC_Z), Vector3(0.46, 4.5, SIDE_HALF_D * 2.0 - 0.5), stone)
	for z in [JUNC_Z - 1.55, JUNC_Z + 1.55]:
		_box(endcap, Vector3(WEST_X + 0.58, 1.55, z), Vector3(0.34, 3.1, 0.30), timber)
	_box(endcap, Vector3(WEST_X + 0.58, 3.10, JUNC_Z), Vector3(0.34, 0.30, 3.4), timber)
	for z in [JUNC_Z - 0.72, JUNC_Z + 0.72]:
		_box(endcap, Vector3(WEST_X + 0.56, 1.42, z), Vector3(0.18, 2.65, 1.32), Color(0.28, 0.17, 0.12))
	_roof(endcap, Vector3(WEST_X + 0.50, 3.85, JUNC_Z), Vector3(2.0, 1.1, 4.6), ROOF_PALETTE[1])
	for z in [JUNC_Z - 3.7, JUNC_Z + 3.7]:
		_box(endcap, Vector3(WEST_X + 0.54, 0.28, z), Vector3(0.64, 0.56, 1.6), stone.darkened(0.10))

func _build_shrine_forecourt(root: Node3D) -> void:
	var forecourt := Node3D.new()
	forecourt.name = "ShrineForecourt"
	root.add_child(forecourt)
	var paver := Color(0.50, 0.48, 0.43)
	for i in 8:
		var z := NORTH_Z - 0.15 - float(i) * 0.92
		_box(forecourt, Vector3(0, 0.025, z), Vector3(4.2, 0.05, 0.78), paver.lightened(0.025 if i % 2 == 0 else 0.0))
	for x in [-4.85, 4.85]:
		_box(forecourt, Vector3(x, 0.34, NORTH_Z - 3.4), Vector3(0.48, 0.68, 7.2), Color(0.37, 0.36, 0.33))
		_box(forecourt, Vector3(x, 0.73, NORTH_Z - 3.4), Vector3(0.62, 0.12, 7.35), Color(0.30, 0.29, 0.27))
	_stone_lantern(forecourt, -4.0, NORTH_Z - 4.8)
	_stone_lantern(forecourt, 4.0, NORTH_Z - 4.8)
	var basin_pos := Vector3(3.75, 0, NORTH_Z - 1.9)
	_box(forecourt, basin_pos + Vector3(0, 0.32, 0), Vector3(0.52, 0.64, 0.52), Color(0.34, 0.33, 0.30))
	_box(forecourt, basin_pos + Vector3(0, 0.76, 0), Vector3(1.25, 0.28, 0.82), Color(0.40, 0.39, 0.36))
	_box(forecourt, basin_pos + Vector3(0, 0.92, 0), Vector3(1.02, 0.05, 0.60), Color(0.25, 0.46, 0.52))

func _build_torii_details(root: Node3D) -> void:
	var details := Node3D.new()
	details.name = "ToriiDetails"
	root.add_child(details)
	var zt := NORTH_Z + 1.5
	for side in [-1.0, 1.0]:
		_box(details, Vector3(side * 4.6, 0.28, zt), Vector3(0.88, 0.56, 0.90), Color(0.12, 0.10, 0.10))
		_box(details, Vector3(side * 4.6, 0.62, zt), Vector3(0.70, 0.16, 0.74), Color(0.30, 0.18, 0.13))
		var end_cap := _box(details, Vector3(side * 5.72, 9.34, zt), Vector3(1.8, 0.30, 0.80), Color(0.50, 0.055, 0.045))
		end_cap.rotation_degrees.z = side * 7.0
	_box(details, Vector3(0, 9.58, zt), Vector3(12.3, 0.18, 0.86), Color(0.16, 0.12, 0.11))
	_architecture_cylinder(details, Vector3(0, 7.42, zt + 0.38), 0.075, 7.0, Color(0.55, 0.40, 0.20), Vector3(0, 0, 90))
	for x in [-2.6, -1.3, 0.0, 1.3, 2.6]:
		_box(details, Vector3(x, 7.02, zt + 0.42), Vector3(0.10, 0.72, 0.06), Color(0.92, 0.89, 0.80))
		_box(details, Vector3(x + 0.10, 6.73, zt + 0.42), Vector3(0.28, 0.12, 0.06), Color(0.92, 0.89, 0.80))
	_box(details, Vector3(0, 8.56, zt + 0.44), Vector3(1.12, 0.62, 0.10), Color(0.18, 0.13, 0.10))
	_box(details, Vector3(0, 8.56, zt + 0.50), Vector3(0.76, 0.34, 0.04), Color(0.72, 0.56, 0.24))

func _build_backdrop_depth(root: Node3D) -> void:
	var backdrop := Node3D.new()
	backdrop.name = "BackdropDepth"
	root.add_child(backdrop)
	var positions := [
		Vector3(WEST_X - 3.2, 2.6, JUNC_Z - 3.4),
		Vector3(WEST_X - 5.8, 3.1, JUNC_Z + 0.4),
		Vector3(WEST_X - 3.8, 2.3, JUNC_Z + 4.0),
	]
	for i in positions.size():
		var pos: Vector3 = positions[i]
		_box(backdrop, pos, Vector3(4.8, pos.y * 2.0, 4.2), Color(0.46, 0.42, 0.36).darkened(float(i) * 0.05))
		_roof(backdrop, Vector3(pos.x, pos.y * 2.0 + 0.75, pos.z), Vector3(5.6, 1.5, 5.0), ROOF_PALETTE[(i + 1) % ROOF_PALETTE.size()])
	for z in [JUNC_Z - 4.2, JUNC_Z, JUNC_Z + 4.2]:
		_architecture_cylinder(backdrop, Vector3(WEST_X - 7.0, 4.5, z), 0.55, 9.0, Color(0.16, 0.28, 0.20), Vector3.ZERO)

func _build_town_details(root: Node3D) -> void:
	var details := Node3D.new()
	details.name = "TownDetails"
	root.add_child(details)
	for z in [-2.0, -10.0, -20.5]:
		for side in [-1.0, 1.0]:
			var side_f := float(side)
			var x := side_f * 5.22
			_box(details, Vector3(x, 2.55, z), Vector3(0.10, 4.6, 0.10), WOOD_DARK)
			_box(details, Vector3(x - side_f * 0.22, 3.68, z), Vector3(0.08, 0.12, 1.4), WOOD_MID)
			_box(details, Vector3(x - side_f * 0.28, 2.85, z), Vector3(0.06, 1.2, 0.64), _norens[int(absf(z)) % _norens.size()].darkened(0.08))

func _architecture_cylinder(root: Node3D, pos: Vector3, radius: float, height: float, color: Color, rotation_deg: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rotation_deg
	mesh_instance.material_override = _flat_mat(color)
	root.add_child(mesh_instance)
	return mesh_instance

const HALL_GLB := "res://assets/3d/landmarks/shrine_hall.glb"
const HALL_H := 10.0

func _build_shrine_hall(root: Node3D) -> void:
	if not ResourceLoader.exists(HALL_GLB):
		push_warning("ShrineStreet: 本殿模型不存在 %s(先略過)" % HALL_GLB)
		return
	var hall := (load(HALL_GLB) as PackedScene).instantiate()
	root.add_child(hall)
	_fix_glb_materials(hall)
	var aabb := _merged_aabb(hall)
	if aabb.size.y > 0.01:
		var s := HALL_H / aabb.size.y
		hall.scale = Vector3(s, s, s)
		hall.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, NORTH_Z - 7.5 - aabb.get_center().z * s)
	# 本殿前暖光（燈籠感、入 _warm_lights 跟時段）
	var l := OmniLight3D.new()
	l.position = Vector3(0, 3.0, NORTH_Z - 4.0)
	l.light_color = Color(1.0, 0.80, 0.46)
	l.light_energy = 1.4
	l.omni_range = 12.0
	root.add_child(l)
	_warm_lights.append([l, 1.4])
	if OS.is_debug_build():
		print("SHRINE_HALL ok")

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

# ── 燈籠（主街 z 向 + 支街 x 向）──────────────────────────
func _lantern(root: Node3D, x: float, z: float) -> void:
	_box(root, Vector3(x, 2.0, z), Vector3(0.25, 4.0, 0.25), WOOD_DARK)
	var glow := MeshInstance3D.new()
	glow.add_to_group("shrine_paper_lantern")
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.36
	cm.height = 0.72
	cm.radial_segments = 12
	glow.mesh = cm
	glow.position = Vector3(x, 4.0, z)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.80, 0.42)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.74, 0.34)
	gm.emission_energy_multiplier = 1.25
	glow.material_override = gm
	root.add_child(glow)
	_warm_mats.append([gm, 1.25])
	_box(root, Vector3(x, 4.40, z), Vector3(0.48, 0.09, 0.48), WOOD_DARK)
	_box(root, Vector3(x, 3.60, z), Vector3(0.48, 0.09, 0.48), WOOD_DARK)
	var l := OmniLight3D.new()
	l.position = Vector3(x, 4.0, z)
	l.light_color = Color(1.0, 0.82, 0.5)
	l.light_energy = 1.0
	l.omni_range = 6.5
	root.add_child(l)
	_warm_lights.append([l, 1.0])

func _build_lanterns(root: Node3D) -> void:
	var z := 0.0
	while z > NORTH_Z + 2.0:
		_lantern(root, 5.6, z)
		if not (z < (JUNC_Z + SIDE_HALF_D) and z > (JUNC_Z - SIDE_HALF_D)):
			_lantern(root, -5.6, z)   # 開口段左燈籠留空
		z -= 8.0
	var x := -10.0
	while x > WEST_X + 2.0:
		_lantern(root, x, JUNC_Z + SIDE_HALF_D + 0.6)
		_lantern(root, x, JUNC_Z - SIDE_HALF_D - 0.6)
		x -= 8.0

## 2026-07-08 邊界破綻修正：原本只有北端+西端林，主街東牆外、南口(回頭看)、
## 支街東端(轉彎口外)都沒有背景收尾——GPU 截圖驗到這些方向直接看穿邊界牆
## 露出純色天空虛空（見 D:\monk\_boundary_audit\shrine_south_entrance_yaw180_*.png、
## shrine_main_ne_corner_yaw45_*.png 等）。補東端林(主街東牆外)＋南端林(南口外，
## 樹列退到 SOUTH_Z+6 避免擋住 spawn 鏡頭)，同款 _tree_row，純視覺無碰撞。
func _build_backdrop(root: Node3D) -> void:
	# 遠景：北端 + 西端 杉林＋山；山染霞藍(空氣遠近感)、杉林綠——遠景也要有顏色
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for mx in [-16.0, -4.0, 9.0]:
		var mh := rng.randf_range(20.0, 30.0)
		_roof(root, Vector3(mx, mh * 0.5 - 2.0, NORTH_Z - 24.0), Vector3(rng.randf_range(22.0, 34.0), mh, 6.0), Color(0.52, 0.60, 0.76), false)
	_tree_row(root, rng, NORTH_Z - 16.0, NORTH_Z - 12.0, -18.0, 18.0, false)   # 北端林
	_tree_row(root, rng, JUNC_Z - 4.0, JUNC_Z + 4.0, WEST_X - 8.0, WEST_X - 4.0, true)  # 西端林（沿 z 排）
	_tree_row(root, rng, MAIN_HALF_W + 10.0, MAIN_HALF_W + 14.0, NORTH_Z - 2.0, SOUTH_Z + 2.0, true)  # 東端林(主街東牆外，x∈[a,b] 沿 z 排)
	_tree_row(root, rng, SOUTH_Z + 6.0, SOUTH_Z + 10.0, -18.0, 18.0, false)   # 南端林(南口外，z∈[a,b] 沿 x 排[c,dd)，退遠避開 spawn 鏡頭)

func _tree_row(root: Node3D, rng: RandomNumberGenerator, a: float, b: float, c: float, dd: float, along_z: bool) -> void:
	var t := c
	while t < dd:
		var th := rng.randf_range(9.0, 17.0)
		var tree := MeshInstance3D.new()
		tree.add_to_group("shrine_backdrop_tree")
		var cyl := CylinderMesh.new()
		cyl.top_radius = rng.randf_range(0.14, 0.24)
		cyl.bottom_radius = rng.randf_range(0.75, 1.25)
		cyl.height = th
		cyl.radial_segments = 8
		tree.mesh = cyl
		if along_z:
			tree.position = Vector3(rng.randf_range(a, b), th * 0.5 - 0.5, t)
		else:
			tree.position = Vector3(t, th * 0.5 - 0.5, rng.randf_range(a, b))
		var g := rng.randf_range(0.82, 1.10)
		tree.material_override = _flat_mat(Color(0.17 * g, 0.31 * g, 0.22 * g))
		root.add_child(tree)
		t += rng.randf_range(2.4, 3.5)

func _stone_lantern(root: Node3D, x: float, z: float) -> void:
	var stone := Color(0.34, 0.33, 0.30)
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
	_warm_mats.append([em, 2.0])
	_roof(root, Vector3(x, 2.2, z), Vector3(1.1, 0.5, 1.1), stone, false)
	var l := OmniLight3D.new()
	l.position = Vector3(x, 1.7, z)
	l.light_color = Color(1.0, 0.8, 0.48)
	l.light_energy = 1.2
	l.omni_range = 6.0
	root.add_child(l)
	_warm_lights.append([l, 1.2])

func _build_stone_lanterns(root: Node3D) -> void:
	var z := -3.0
	while z > NORTH_Z + 2.0:
		if z < (JUNC_Z + SIDE_HALF_D) and z > (JUNC_Z - SIDE_HALF_D):
			z -= 9.0
			continue
		_stone_lantern(root, 4.2, z)
		_stone_lantern(root, -4.2, z)
		z -= 9.0
	var x := -13.0
	while x > WEST_X + 3.0:
		_stone_lantern(root, x, JUNC_Z + SIDE_HALF_D - 1.3)
		_stone_lantern(root, x, JUNC_Z - SIDE_HALF_D + 1.3)
		x -= 9.0

func _build_props(root: Node3D) -> void:
	# 幟(直幡)＋路邊道具(酒樽/木箱)增加生活感與垂直節奏（主街）
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var z := -1.0
	var flip := 0
	while z > NORTH_Z + 2.0:
		if not (z < (JUNC_Z + SIDE_HALF_D) and z > (JUNC_Z - SIDE_HALF_D)):
			var side := 1 if flip % 2 == 0 else -1
			var x := float(side) * 5.2
			_box(root, Vector3(x, 2.4, z), Vector3(0.12, 4.8, 0.12), WOOD_DARK)
			var cloth: Color = [Color(0.80, 0.20, 0.14), Color(0.94, 0.91, 0.84)][flip % 2]
			_box(root, Vector3(x + float(side) * 0.35, 3.0, z), Vector3(0.06, 3.0, 0.7), cloth)
		flip += 1
		z -= rng.randf_range(6.0, 8.0)
	var k := 0
	z = -5.0
	while z > NORTH_Z + 3.0:
		if z < (JUNC_Z + SIDE_HALF_D) and z > (JUNC_Z - SIDE_HALF_D):
			z -= 8.0
			continue
		var side2 := -1 if k % 2 == 0 else 1
		var bx := float(side2) * 3.4
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.9
		bar.mesh = cm
		bar.position = Vector3(bx, 0.45, z)
		bar.material_override = _flat_mat(Color(0.40, 0.30, 0.18))
		root.add_child(bar)
		_box(root, Vector3(bx + float(side2) * 0.9, 0.35, z + 0.4), Vector3(0.7, 0.7, 0.7), Color(0.44, 0.34, 0.22))
		k += 1
		z -= rng.randf_range(7.0, 9.0)
	# 支街西端擺幾個木箱點綴
	var xw := -16.0
	var f2 := 0
	while xw > WEST_X + 3.0:
		var zc := JUNC_Z + (SIDE_HALF_D - 1.4) * (1 if f2 % 2 == 0 else -1)
		_box(root, Vector3(xw, 0.35, zc), Vector3(0.7, 0.7, 0.7), Color(0.44, 0.34, 0.22))
		_box(root, Vector3(xw + 0.3, 0.95, zc + 0.2), Vector3(0.5, 0.5, 0.5), Color(0.40, 0.31, 0.20))
		f2 += 1
		xw -= rng.randf_range(6.0, 8.0)

# ── 櫻花樹（彩色點綴主角）＋卡通雲 ─────────────────────────
## 深棕幹＋粉團樹冠(toon 球)＋樹下花瓣粒子。擺在街緣(可走範圍邊)：轉彎口/鳥居旁/支街西端。
## 樹要夠高(h≥4.4)讓樹冠浮在雨庇(頂約3.5)之上，不然粉球會插進店面；南口不擺(擋 spawn 鏡頭)。
func _build_sakura(root: Node3D) -> void:
	_sakura_tree(root, Vector3(-4.4, 0, JUNC_Z - SIDE_HALF_D - 1.0), 4.8)   # 轉彎口地標
	_sakura_tree(root, Vector3(-4.5, 0, NORTH_Z + 4.5), 5.2)                # 鳥居旁一對
	_sakura_tree(root, Vector3(4.5, 0, NORTH_Z + 5.5), 4.6)
	_sakura_tree(root, Vector3(WEST_X + 2.5, 0, JUNC_Z + SIDE_HALF_D - 1.0), 4.6)

func _sakura_tree(root: Node3D, pos: Vector3, h: float) -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.22
	cm.height = h
	trunk.mesh = cm
	trunk.position = pos + Vector3(0, h * 0.5, 0)
	trunk.material_override = _flat_mat(Color(0.30, 0.21, 0.16))
	root.add_child(trunk)
	for angle in [-48.0, -18.0, 38.0]:
		_architecture_cylinder(root, pos + Vector3(0, h * 0.78, 0), 0.075, h * 0.42, Color(0.30, 0.21, 0.16), Vector3(0, 0, angle))
	# 樹冠＝數顆交疊粉球，兩色粉交錯避免死板
	var blobs := [
		[Vector3(0.0, 0.0, 0.0), 1.25], [Vector3(0.80, -0.30, 0.35), 0.90],
		[Vector3(-0.72, -0.25, -0.25), 0.85], [Vector3(0.18, -0.42, -0.75), 0.78],
		[Vector3(-0.25, 0.42, 0.48), 0.82],
	]
	for bi in blobs.size():
		var b: Array = blobs[bi]
		var blob := MeshInstance3D.new()
		blob.add_to_group("shrine_sakura_canopy")
		var sm := SphereMesh.new()
		sm.radius = b[1]
		sm.height = b[1] * 1.7
		blob.mesh = sm
		blob.position = pos + Vector3(0, h + 0.35, 0) + (b[0] as Vector3)
		blob.scale = Vector3(1.0 + float(bi % 2) * 0.12, 0.58, 0.82 + float((bi + 1) % 2) * 0.10)
		blob.rotation_degrees.y = float(bi) * 31.0
		var pink := Color(0.96, 0.74, 0.81) if bi % 2 == 0 else Color(0.93, 0.60, 0.72)
		blob.material_override = _flat_mat(pink)
		root.add_child(blob)
	# 樹下花瓣粒子（小範圍、比街道落葉密）
	var p := GPUParticles3D.new()
	p.amount = 36
	p.lifetime = 5.0
	p.position = pos + Vector3(0, h + 0.6, 0)
	p.visibility_aabb = AABB(Vector3(-3.5, -h - 2.0, -3.5), Vector3(7.0, h + 4.0, 7.0))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.gravity = Vector3(0, -0.5, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 2.2
	p.process_material = pm
	var petal := QuadMesh.new()
	petal.size = Vector2(0.07, 0.12)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lm.albedo_color = Color(0.97, 0.70, 0.79)
	petal.material = lm
	p.draw_pass_1 = petal
	root.add_child(p)

# ── 花盆花草（參考圖的盆花感）─────────────────────────────
## 陶盆＋綠叢＋花球，沿街緣與燈籠腳點綴；轉彎口開口段不擺（同燈籠留空邏輯）。
func _build_flowers(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var z := -2.5
	var k := 0
	while z > NORTH_Z + 3.0:
		if not (z < (JUNC_Z + SIDE_HALF_D) and z > (JUNC_Z - SIDE_HALF_D)):
			var side := 1 if k % 2 == 0 else -1
			_flower_pot(root, Vector3(float(side) * 4.9, 0, z), rng)
			if rng.randf() < 0.45:   # 偶爾對面也擺一盆
				_flower_pot(root, Vector3(float(-side) * 4.9, 0, z + rng.randf_range(-0.8, 0.8)), rng)
		k += 1
		z -= rng.randf_range(3.5, 5.5)
	var xx := -12.0
	var f := 0
	while xx > WEST_X + 3.0:
		var zc := JUNC_Z + (SIDE_HALF_D - 0.7) * (1.0 if f % 2 == 0 else -1.0)
		_flower_pot(root, Vector3(xx, 0, zc), rng)
		f += 1
		xx -= rng.randf_range(4.0, 6.0)

const BLOSSOM_COLS := [
	Color(0.86, 0.22, 0.30), Color(0.95, 0.55, 0.70), Color(0.62, 0.42, 0.82),
	Color(0.96, 0.93, 0.88), Color(0.94, 0.60, 0.20),
]

func _flower_pot(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var pot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.18
	cm.height = 0.38
	pot.mesh = cm
	pot.position = pos + Vector3(0, 0.19, 0)
	pot.material_override = _flat_mat(Color(0.70, 0.40, 0.27))   # 素燒陶
	root.add_child(pot)
	var bush := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.30
	sm.height = 0.52
	bush.mesh = sm
	bush.position = pos + Vector3(0, 0.52, 0)
	bush.material_override = _flat_mat(Color(0.28, 0.50, 0.30))
	root.add_child(bush)
	var col: Color = BLOSSOM_COLS[rng.randi() % BLOSSOM_COLS.size()]
	for bi in range(rng.randi_range(3, 5)):
		var blossom := MeshInstance3D.new()
		var bs := SphereMesh.new()
		var r := rng.randf_range(0.06, 0.10)
		bs.radius = r
		bs.height = r * 2.0
		blossom.mesh = bs
		blossom.position = pos + Vector3(rng.randf_range(-0.18, 0.18), 0.68 + rng.randf_range(0.0, 0.12), rng.randf_range(-0.18, 0.18))
		blossom.material_override = _flat_mat(col.lightened(rng.randf_range(0.0, 0.15)))
		root.add_child(blossom)

## 卡通雲：北/西遠處高空幾團壓扁白球(unshaded)，albedo 進 _cloud_mats 跟時段染色。
func _build_clouds(root: Node3D) -> void:
	var defs := [
		Vector3(-30, 30, -75), Vector3(8, 26, -82), Vector3(35, 33, -62),
		Vector3(-62, 28, -30), Vector3(-20, 37, -95), Vector3(-70, 32, 5),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for c in defs:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1)
		_cloud_mats.append(m)
		var s := rng.randf_range(5.0, 9.0)
		for off in [Vector3.ZERO, Vector3(s * 0.85, -s * 0.12, 0.5), Vector3(-s * 0.8, -s * 0.15, -0.5)]:
			var blob := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := s * (0.55 if off == Vector3.ZERO else 0.4)
			sm.radius = r
			sm.height = r * 0.9   # 壓扁
			blob.mesh = sm
			blob.position = c + (off as Vector3)
			blob.material_override = m
			root.add_child(blob)
