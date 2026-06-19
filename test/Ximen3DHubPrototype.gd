extends Node3D

const BATTLE_ENEMY_ID := "street_punk"
const BATTLE_CLEAR_FLAG := "ximen_ambush_cleared"
const BATTLE_RETURN_SCENE := "res://test/TestXimen3DHub.tscn"

const HOTSPOTS := [
	{"id": "npc", "label": "Talk: neon monk informant", "position": Vector3(-2.4, 0.1, 1.4), "radius": 1.25},
	{"id": "battle", "label": "Ambush: alley shadows", "position": Vector3(0.2, 0.1, -8.3), "radius": 1.35},
	{"id": "exit", "label": "Exit: return to city map", "position": Vector3(0.0, 0.1, 10.4), "radius": 1.3},
]

@onready var hint: Label = $HUD/Hint
@onready var objective: Label = $HUD/Objective
@onready var status: Label = $HUD/Status

var _active_hotspot: Area3D = null
var _base_hint := "Ximen 3D Hub prototype - WASD / arrow keys to move"

func _ready() -> void:
	_base_hint = hint.text
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
