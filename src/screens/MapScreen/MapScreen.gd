extends Node3D

const TRIGGER_SCENE := preload("res://src/screens/MapScreen/LocationTrigger.tscn")

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD

var _locations: Dictionary = {}
var _current_loc: String   = ""
var _in_trigger: bool      = false

func _ready() -> void:
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_build_triggers()
	_update_hud()
	GameManager.time_advanced.connect(_on_time_advanced)
	var p: Dictionary = GameManager.player.last_position
	player.global_position = Vector3(p.x, p.y, p.z)
	AudioManager.switch_bgm("temple_ambient")

func _build_triggers() -> void:
	for id in _locations:
		var loc: Dictionary = _locations[id]
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
			continue
		var t := TRIGGER_SCENE.instantiate()
		t.setup(id, loc)
		t.player_entered.connect(_on_entered.bind(id))
		t.player_exited.connect(_on_exited)
		add_child(t)

func _input(event: InputEvent) -> void:
	if _in_trigger and event.is_action_pressed("interact"):
		_open_menu(_current_loc)

func _on_entered(id: String) -> void:
	_in_trigger = true
	_current_loc = id
	hud.show_prompt("[E] %s" % _locations[id].name)
	EventBus.location_entered.emit(id)

func _on_exited() -> void:
	_in_trigger = false
	_current_loc = ""
	hud.hide_prompt()
	hud.hide_action_menu()
	EventBus.location_exited.emit()

func _open_menu(id: String) -> void:
	var loc: Dictionary = _locations[id]
	hud.show_action_menu(loc.name, loc.actions, perform_action)

func perform_action(action: String) -> void:
	hud.hide_action_menu()
	GameManager.advance_time(1)
	match action:
		"random_encounter":
			var district: String = _locations[_current_loc].district
			EventBus.random_encounter_triggered.emit(district)
			SceneRouter.go_to_battle(_pick_enemy(district))
		"cherry_dialogue":
			if ResourceLoader.exists("res://dialogue/cherry_first_meeting.dtl"):
				Dialogic.start("cherry_first_meeting")
			else:
				hud.show_toast("Cherry 對話尚未製作（Step 7）")
		"food_break_trigger":
			BreakVowSystem.try_trigger("food")
		"greed_break_trigger":
			BreakVowSystem.try_trigger("greed")
		"lust_break_trigger":
			BreakVowSystem.try_trigger("lust")
		"beggar_minigame":
			SceneRouter.go_to_minigame("beggar_challenge")
			hud.show_toast("化緣小遊戲尚未實作（Step 9）")
		"save":
			_store_position()
			SaveManager.save_game()
			AudioManager.play_sfx("save_done")
			hud.show_toast("存檔完成")
		"job_switch":
			hud.open_job_menu()
		"rest":
			GameManager.heal(150)
			hud.show_toast("休息片刻，恢復了體力")
		"shop", "skill_learn":
			hud.show_toast("此功能尚未實作")
		_:
			if action.begins_with("quest_"):
				QuestManager.trigger_action(action, _current_loc)
				hud.show_toast("支線對話尚未製作（Step 7）")
	_update_hud()

func get_player_position() -> Vector3:
	return player.global_position

func _store_position() -> void:
	var pos := player.global_position
	GameManager.player.last_position = {"x": pos.x, "y": pos.y, "z": pos.z}

func _pick_enemy(district: String) -> String:
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	var pool: Array = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if e.get("district", "") != district:
			continue
		if e.has("time_restriction") and GameManager.player.period not in e.time_restriction:
			continue
		pool.append(id)
	if pool.is_empty():
		return "street_punk"
	return pool[randi() % pool.size()]

func _on_time_advanced(_p: int) -> void:
	_update_hud()
	for t in get_tree().get_nodes_in_group("location_trigger"):
		var loc: Dictionary = _locations.get(t.location_id, {})
		t.visible = GameManager.player.period in loc.get("available_periods", [0, 1, 2, 3])

func _update_hud() -> void:
	hud.set_time(GameManager.player.day, GameManager.TIME_PERIODS[GameManager.player.period])
	hud.update_stats()
