extends Node3D
## 可玩的西門 3D Hub：程序化長街（模組件重複鋪）+ 氛圍 + 第三人稱走動 + 三個互動熱點。
## 街沿 -Z 延伸；玩家從近端(+Z)往深處(-Z)走：exit(回地圖)→npc(情報對話)→battle(埋伏戰)。

const BATTLE_ENEMY_ID := "street_punk"
const BATTLE_CLEAR_FLAG := "ximen_ambush_cleared"
const BATTLE_RETURN_SCENE := "res://test/TestXimen3DHub.tscn"

# 熱點沿長街擺：exit 近端身後、npc 半途、battle 街尾
const HOTSPOTS := [
	{"id": "exit", "label": "Exit: return to city map", "position": Vector3(0.0, 0.1, 13.5), "radius": 1.4},
	{"id": "npc", "label": "Talk: neon monk informant", "position": Vector3(-2.6, 0.1, -8.0), "radius": 1.3},
	{"id": "battle", "label": "Ambush: alley shadows", "position": Vector3(0.4, 0.1, -34.0), "radius": 1.5},
]

# ── 長街素材（模組件重用）──
const DIR := "res://assets/3d/environments/ximen/prototypes/"
const BUILDINGS := [
	"ximen_storefront_facade_01", "ximen_apartment_facade_01",
	"ximen_corner_shophouse_01", "ximen_mrt_exit_01",
	"ximen_convenience_entrance_01",
]
const WALL_SIGNS := ["ximen_neon_sign_cluster_01", "ximen_neon_horizontal_01"]
const POLE_SIGN := "ximen_neon_vertical_01"
const CLUTTER := ["ximen_street_clutter_01", "ximen_street_clutter_02"]
const STREET_NEAR := 11.0
const STREET_FAR := -42.0
const SIDE_X := 6.4

@onready var hint: Label = $HUD/Hint
@onready var objective: Label = $HUD/Objective
@onready var status: Label = $HUD/Status

var _active_hotspot: Area3D = null
var _base_hint := "Ximen 3D Hub prototype - WASD / arrow keys to move"
var _rng := RandomNumberGenerator.new()
var _neon_cols := [Color(1.0, 0.18, 0.7), Color(0.2, 0.85, 1.0), Color(1.0, 0.6, 0.2), Color(0.7, 0.3, 1.0)]

func _ready() -> void:
	_base_hint = hint.text
	_build_world()
	if bool(GameManager.get_flag("battle_return_restore_last_position", false)):
		_restore_last_player_position()
		GameManager.player.flags["battle_return_restore_last_position"] = false
	_build_hotspots()
	_update_hud_state()
	_set_hint(_base_hint)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _active_hotspot != null:
		_perform_hotspot(String(_active_hotspot.get_meta("hub_action")))

func get_player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO

# ─── 程序化世界（地面/牆/長街/霓虹）────────────────────────────
func _build_world() -> void:
	_rng.seed = 20260619
	var street_kit := get_node_or_null("StreetKit") as Node3D
	if street_kit == null:
		street_kit = Node3D.new()
		street_kit.name = "StreetKit"
		add_child(street_kit)
	var neon := Node3D.new()
	neon.name = "Neon"
	add_child(neon)
	_build_ground_and_walls()
	_build_street(street_kit, neon)

func _build_ground_and_walls() -> void:
	var mid := (STREET_NEAR + STREET_FAR) * 0.5
	var length: float = abs(STREET_NEAR - STREET_FAR) + 8.0
	# 地面（mesh + 碰撞）
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, length)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.06, 0.085)
	gmat.metallic = 0.35
	gmat.roughness = 0.22
	ground.mesh.surface_set_material(0, gmat)
	ground.position = Vector3(0, 0, mid)
	add_child(ground)
	var gbody := StaticBody3D.new()
	add_child(gbody)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(16, 1, length)
	gcol.shape = gshape
	gcol.position = Vector3(0, -0.5, mid)
	gbody.add_child(gcol)
	# 兩側看不見的擋牆（把玩家留在走道上）
	for sgn in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		add_child(wall)
		var wcol := CollisionShape3D.new()
		var wshape := BoxShape3D.new()
		wshape.size = Vector3(1, 4, length)
		wcol.shape = wshape
		wcol.position = Vector3(sgn * 5.4, 1.8, mid)
		wall.add_child(wcol)
	# 微弱夜光主光
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_energy = 0.4
	moon.light_color = Color(0.5, 0.6, 0.9)
	add_child(moon)

func _build_street(kit: Node3D, neon: Node3D) -> void:
	# 兩側交替鋪建築
	var z := STREET_NEAR
	var side := -1.0
	var bidx := 0
	while z > STREET_FAR:
		var model: String = BUILDINGS[bidx % BUILDINGS.size()]
		bidx += _rng.randi_range(1, 2)
		var x := side * (SIDE_X + _rng.randf_range(-0.4, 0.7))
		var yaw := (90.0 if side < 0.0 else -90.0) + _rng.randf_range(-4.0, 4.0)
		_place(kit, model, Vector3(x, 0, z), yaw, _rng.randf_range(3.6, 5.6), "H", 0.0)
		side = -side
		z -= _rng.randf_range(3.2, 4.4)
	# 牆面招牌 + 霓虹
	var sz := STREET_NEAR - 4.0
	var sside := 1.0
	while sz > STREET_FAR + 4.0:
		var sign: String = WALL_SIGNS[_rng.randi() % WALL_SIGNS.size()]
		var sx := sside * (SIDE_X - 1.6)
		_place(kit, sign, Vector3(sx, 0, sz), (90.0 if sside < 0.0 else -90.0), _rng.randf_range(2.4, 3.2), "S", _rng.randf_range(2.6, 3.6))
		_neon(neon, Vector3(sx, _rng.randf_range(2.6, 3.4), sz), _neon_cols[_rng.randi() % _neon_cols.size()], 4.5, 9.0)
		sside = -sside
		sz -= _rng.randf_range(5.5, 7.5)
	# 直立招牌站街緣
	for zz in [4.0, -9.0, -22.0, -33.0]:
		var ps := -1.0 if _rng.randf() < 0.5 else 1.0
		var px := ps * (SIDE_X - 2.6)
		_place(kit, POLE_SIGN, Vector3(px, 0, zz), (90.0 if ps < 0 else -90.0), 3.6, "S", 0.0)
		_neon(neon, Vector3(px, 2.2, zz), _neon_cols[_rng.randi() % _neon_cols.size()], 4.0, 8.0)
	# 小吃攤（近處 hero prop）
	_place(kit, "ximen_food_stall_01", Vector3(2.0, 0, 4.0), 205.0, 2.3, "S", 0.0)
	_neon(neon, Vector3(2.0, 1.2, 4.0), Color(1.0, 0.55, 0.2), 3.5, 6.0)
	# 路燈桿 + 雜物散沿街
	for zz in [-2.0, -15.0, -28.0]:
		_place(kit, "ximen_utility_pole_light_01", Vector3((-1.0 if int(zz) % 2 == 0 else 1.0) * (SIDE_X - 2.2), 0, zz), 0.0, 3.4, "S", 0.0)
	var cz := 6.0
	while cz > STREET_FAR + 4.0:
		_place(kit, CLUTTER[_rng.randi() % CLUTTER.size()], Vector3((-1.0 if _rng.randf() < 0.5 else 1.0) * _rng.randf_range(2.0, 3.0), 0, cz), _rng.randf_range(0, 360), 1.9, "S", 0.0)
		cz -= _rng.randf_range(7.0, 10.0)
	# 街心地面霓虹光池
	var lz := STREET_NEAR - 3.0
	while lz > STREET_FAR:
		_neon(neon, Vector3(_rng.randf_range(-1.5, 1.5), 0.4, lz), _neon_cols[_rng.randi() % _neon_cols.size()], 2.4, 9.0)
		lz -= _rng.randf_range(5.0, 7.0)

func _neon(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_range: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_range
	l.light_specular = 1.0
	parent.add_child(l)

func _place(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, target: float, mode: String, y_offset: float) -> void:
	var ps := load(DIR + name + ".glb") as PackedScene
	if ps == null:
		push_warning("hub: missing prop %s" % name); return
	var inst := ps.instantiate() as Node3D
	parent.add_child(inst)
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

# ─── 互動熱點 ──────────────────────────────────────────────
func _build_hotspots() -> void:
	var parent := Node3D.new()
	parent.name = "Hotspots"
	add_child(parent)
	for data in HOTSPOTS:
		if not _is_hotspot_available(String(data.id)):
			continue
		var area := Area3D.new()
		area.name = "%sHotspot" % String(data.id).to_pascal_case()
		area.position = data.position
		area.set_meta("hub_action", data.id)
		area.set_meta("hub_label", data.label)
		area.add_to_group("ximen_hub_hotspot")
		area.body_entered.connect(_on_hotspot_body_entered.bind(area))
		area.body_exited.connect(_on_hotspot_body_exited.bind(area))

		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = float(data.radius)
		shape.shape = sphere
		area.add_child(shape)

		var marker := MeshInstance3D.new()
		marker.name = "Marker"
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(data.radius)
		mesh.bottom_radius = float(data.radius)
		mesh.height = 0.04
		mesh.radial_segments = 32
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = _marker_color(String(data.id))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		marker.mesh = mesh
		marker.position.y = 0.03
		area.add_child(marker)

		parent.add_child(area)

func _on_hotspot_body_entered(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	_active_hotspot = area
	_set_hint("E: %s" % String(area.get_meta("hub_label")))

func _on_hotspot_body_exited(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if _active_hotspot == area:
		_active_hotspot = null
		_set_hint(_base_hint)

func _perform_hotspot(action: String) -> void:
	match action:
		"npc":
			_start_npc_dialogue()
		"battle":
			_prepare_battle_return()
			_set_hint("Ambush triggered - loading battle...")
			SceneRouter.go_to_battle(BATTLE_ENEMY_ID)
		"exit":
			_exit_to_map()
		_:
			_set_hint(_base_hint)

func _dialogue_timeline() -> String:
	return "main_ch1_intel"

func _battle_flag_key() -> String:
	return BATTLE_CLEAR_FLAG

func _battle_return_scene() -> String:
	return BATTLE_RETURN_SCENE

func _is_hotspot_available(id: String) -> bool:
	if id == "battle":
		return not bool(GameManager.get_flag(_battle_flag_key(), false))
	return true

func _prepare_battle_return() -> void:
	GameManager.player.flags["battle_return_scene"] = _battle_return_scene()
	GameManager.player.flags["battle_return_restore_last_position"] = true
	GameManager.player.flags["battle_clear_flag_on_win"] = _battle_flag_key()

func _start_npc_dialogue() -> void:
	var timeline := _dialogue_timeline()
	if ResourceLoader.exists("res://dialogue/%s.dtl" % timeline):
		_set_hint("Opening dialogue: %s" % timeline)
		GameManager.set_flag("ximen_informant_met", true)
		_update_hud_state()
		Dialogic.start(timeline)
	else:
		_set_hint("Dialogue missing: %s" % timeline)

func _exit_to_map() -> void:
	_set_hint("Returning to city map...")
	SceneRouter.go_to_map()

func _restore_last_player_position() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var pos: Dictionary = GameManager.player.get("last_position", {})
	if pos.is_empty():
		return
	player.global_position = Vector3(
		float(pos.get("x", player.global_position.x)),
		float(pos.get("y", player.global_position.y)),
		float(pos.get("z", player.global_position.z))
	)

func _quest_objective_text() -> String:
	if bool(GameManager.get_flag(_battle_flag_key(), false)):
		return "Objective: Exit the street or keep exploring"
	if bool(GameManager.get_flag("ximen_informant_met", false)):
		return "Objective: Clear the alley ambush"
	return "Objective: Talk to the informant, then clear the alley ambush"

func _status_text() -> String:
	if bool(GameManager.get_flag(_battle_flag_key(), false)):
		return "Ambush: cleared"
	if bool(GameManager.get_flag("ximen_informant_met", false)):
		return "Ambush: active - red marker"
	return "Ambush: active - find intel first"

func _update_hud_state() -> void:
	if objective:
		objective.text = _quest_objective_text()
	if status:
		status.text = _status_text()

func _set_hint(text: String) -> void:
	if hint:
		hint.text = text

func _marker_color(id: String) -> Color:
	match id:
		"npc":
			return Color(0.25, 0.8, 1.0, 0.35)
		"battle":
			return Color(1.0, 0.12, 0.2, 0.38)
		"exit":
			return Color(1.0, 0.72, 0.2, 0.32)
		_:
			return Color(1, 1, 1, 0.25)
