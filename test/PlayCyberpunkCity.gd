extends Node
## 把下載的 Cyberpunk City（golukumar, CC-BY）做成可走 demo：
## glb（放大 ENV_SCALE 倍）＋ 走廊隱形牆 ＋ 保底地面/夜空 ＋ 街面霓虹補光，丟進正牌 Player.tscn。
## 滑鼠轉視角、滾輪縮放、方向鍵走動、Esc 關。夜景後製同 CaptureCyberpunkCity。
## 跑法（視窗）：tools/godot/Godot_v4.5-stable_win64_console.exe --path D:/monk/MONK res://test/PlayCyberpunkCity.tscn
## 自檢：上面指令尾端加 ` -- smoke`（角色落定後截圖 _cyberpunk_city_play.png、印 on_floor/moved 並自動關）

const GLB := "res://assets/3d/environments/cyberpunk_city/cyberpunk_city.glb"
const PLAYER := "res://src/screens/MapScreen/Player.tscn"
const ENV_SCALE := 17.0   # 這場景是壓縮尺度的 Times Square，放大讓角色相對變小才合理
const ROAD_Y := 0.0      # 路面高度（原始 glb 路面≈y0，依原點等比放大後仍在 0）
const MOUSE_SENS := 0.005

var _player: CharacterBody3D
var _cam: Camera3D
var _yaw := 0.0          # 環繞鏡頭：水平角
var _pitch := 0.35       # 仰角（正＝鏡頭在上往下看）
var _cam_dist := 5.0     # 與角色距離（滾輪縮放）

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame

	# 3D 降採樣（最便宜的 FPS 大補丸：3D 用 70% 解析度算、再上採樣，UI 不受影響）
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.7
	vp.msaa_3d = Viewport.MSAA_DISABLED

	_build_env(root)

	# 場景本體（純視覺）。碰撞不逐 mesh 生（會把街道塞死/算到當機），
	# 改用下方 _corridor_walls 圍一條乾淨走廊。
	var city := (load(GLB) as PackedScene).instantiate() as Node3D
	city.scale = Vector3.ONE * ENV_SCALE          # 放大世界，角色相對變小
	root.add_child(city)
	await get_tree().process_frame

	var aabb := _combined_aabb(city)
	var center := aabb.get_center()
	var along_x: bool = aabb.size.x >= aabb.size.z   # 長水平軸＝街向
	var long_len: float = aabb.size.x if along_x else aabb.size.z

	# 視覺保底地面（深色微反光，鋪滿避免邊緣露虛空）
	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var gsize: float = maxf(aabb.size.x, aabb.size.z) * 1.6   # 鋪到比場景更大，邊緣藏進遠處建築/霧裡，街尾不再露虛空
	pm.size = Vector2(gsize, gsize)
	gp.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.22, 0.22, 0.26)   # 中性水泥灰、非金屬：平光下也看得見，不再因反射不到而全黑
	gmat.metallic = 0.0
	gmat.roughness = 0.95
	gp.material_override = gmat
	gp.position = Vector3(center.x, ROAD_Y - 0.02, center.z)
	root.add_child(gp)

	# 碰撞保底地面（無限平面，防角色掉進虛空）
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	cs.position = Vector3(0, ROAD_Y, 0)
	ground.add_child(cs)
	root.add_child(ground)

	# 走廊隱形牆（兩側＋兩端，把角色框在街上）
	_corridor_walls(root, center, along_x, long_len, aabb.size)

	# （已關閉）街面霓虹補光 — 先看素材真實樣貌
	# _street_neons(root, center, along_x, long_len)

	# Player：站街頭、往街心走
	_player = (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	root.add_child(_player)
	_player.global_position = (
		Vector3(center.x - long_len * 0.5 + 3.0 * ENV_SCALE, ROAD_Y + 1.0, center.z) if along_x
		else Vector3(center.x, ROAD_Y + 1.0, center.z - long_len * 0.5 + 3.0 * ENV_SCALE)
	)

	# 環繞第三人稱相機（滑鼠轉視角、滾輪縮放）
	_yaw = -PI * 0.5 if along_x else PI
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 2000.0
	_cam.current = true
	root.add_child(_cam)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_orbit_cam()

	print("PLAY_CYBERPUNK ready — 方向鍵走動，Esc 關")

	if OS.get_cmdline_user_args().has("smoke"):
		await _smoke()

func _process(_delta: float) -> void:
	_orbit_cam()

func _orbit_cam() -> void:
	if _player == null or _cam == null:
		return
	var target := _player.global_position + Vector3(0, 1.5, 0)
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.global_position = target + dir * _cam_dist
	_cam.look_at(target, Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch + event.relative.y * MOUSE_SENS, -0.2, 1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = maxf(2.0, _cam_dist - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = minf(25.0, _cam_dist + 0.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit(0)

func _smoke() -> void:
	for i in 30:   # 讓角色落地穩定
		await get_tree().process_frame
	var start := _player.global_position
	Input.action_press("ui_up")                  # 模擬按住前進，驗證沒被盒子困住
	for i in 90:
		await get_tree().process_frame
	Input.action_release("ui_up")
	var moved := start.distance_to(_player.global_position)
	await RenderingServer.frame_post_draw
	print("SMOKE on_floor=", _player.is_on_floor(), " moved=", moved)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_cyberpunk_city_play.png")
	print("SMOKE_SAVED _cyberpunk_city_play.png ", img.get_width(), "x", img.get_height())
	get_tree().quit()

func _corridor_walls(root: Node3D, center: Vector3, along_x: bool, long_len: float, scene_size: Vector3) -> void:
	var cross: float = scene_size.z if along_x else scene_size.x
	var half_w: float = cross * 0.5 * 0.35     # 走廊半寬＝橫向半幅的 35%（隨世界放大等比）
	const WALL_H := 8.0
	const T := 0.4
	var cy := ROAD_Y + WALL_H * 0.5
	var half := long_len * 0.5
	if along_x:
		_wall(root, Vector3(center.x, cy, center.z + half_w), Vector3(long_len, WALL_H, T))   # 兩側
		_wall(root, Vector3(center.x, cy, center.z - half_w), Vector3(long_len, WALL_H, T))
		_wall(root, Vector3(center.x + half, cy, center.z), Vector3(T, WALL_H, half_w * 2))    # 兩端
		_wall(root, Vector3(center.x - half, cy, center.z), Vector3(T, WALL_H, half_w * 2))
	else:
		_wall(root, Vector3(center.x + half_w, cy, center.z), Vector3(T, WALL_H, long_len))
		_wall(root, Vector3(center.x - half_w, cy, center.z), Vector3(T, WALL_H, long_len))
		_wall(root, Vector3(center.x, cy, center.z + half), Vector3(half_w * 2, WALL_H, T))
		_wall(root, Vector3(center.x, cy, center.z - half), Vector3(half_w * 2, WALL_H, T))

func _wall(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.position = pos
	body.add_child(cs)
	root.add_child(body)

func _build_env(root: Node3D) -> void:
	# 收斂版夜氛圍：冷調夜空給環境光 ＋ 輝光讓「素材自己的招牌」泛光 ＋ 淡霧拉縱深，
	# 不撒任何彩色點光（那是上一版「一堆彩燈」的來源）。
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.09, 0.20)
	sky_mat.sky_horizon_color = Color(0.24, 0.20, 0.34)      # 地平線帶城市光暈
	sky_mat.ground_bottom_color = Color(0.04, 0.04, 0.08)
	sky_mat.ground_horizon_color = Color(0.24, 0.20, 0.34)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.26)
	env.fog_density = 0.006   # 加濃一點：把街尾遠處邊界/地面邊緣收進霧裡（近處仍清楚）
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# 單一柔和冷調月光（給建築一點立體感；不開陰影＝便宜），不是彩燈。
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.light_energy = 0.85
	moon.light_color = Color(0.6, 0.68, 0.95)
	root.add_child(moon)

func _street_neons(root: Node3D, center: Vector3, along_x: bool, long_len: float) -> void:
	var cols := [Color(1.0, 0.18, 0.7), Color(0.2, 0.85, 1.0), Color(1.0, 0.6, 0.2), Color(0.7, 0.3, 1.0)]
	var n := 8
	for i in n:
		var t := float(i) / float(n - 1) - 0.5      # -0.5..0.5
		var pos := (
			Vector3(center.x + t * long_len * 0.9, ROAD_Y + 2.5, center.z) if along_x
			else Vector3(center.x, ROAD_Y + 2.5, center.z + t * long_len * 0.9)
		)
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = cols[i % cols.size()]
		l.light_energy = 4.0
		l.omni_range = 14.0 * ENV_SCALE
		l.light_specular = 1.0
		root.add_child(l)

func _combined_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _all_mesh_instances(node):
		var mi := c as MeshInstance3D
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a; first = false
		else:
			out = out.merge(a)
	return out

func _all_mesh_instances(node: Node) -> Array:
	var arr: Array = []
	if node is MeshInstance3D:
		arr.append(node)
	for ch in node.get_children():
		arr.append_array(_all_mesh_instances(ch))
	return arr
