extends Control
## 2D 探索地圖協調者：持有 DistrictScene/(後續)LocationInterior/CityMap + HUD，沿用所有後端。

const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")
const SHOP_SCREEN := preload("res://src/ui/menu/ShopScreen.gd")

@onready var district: Control = $DistrictScene
@onready var interior: Control = $LocationInterior
@onready var city: Control = $CityMap
@onready var hud: CanvasLayer = $HUD

var _areas: Dictionary = {}
var _locations: Dictionary = {}
var _current_area: String = ""
var _current_loc: String = ""

func _ready() -> void:
	_areas = JsonLoader.load_json("res://data/areas.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_current_area = String(GameManager.player.get("current_area", "ximen"))
	district.location_entered.connect(_on_location_entered)
	district.edge_to.connect(_on_edge_to)
	district.request_city_map.connect(show_city_map)
	interior.left.connect(leave_location)
	city.district_selected.connect(travel_to)
	GameManager.time_advanced.connect(_on_time_advanced)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	_drain_pending_achievements()
	var arrival_x := -1.0
	if not GameManager.pending_arrival.is_empty() \
			and String(GameManager.pending_arrival.get("area", "")) == _current_area:
		arrival_x = float(GameManager.pending_arrival.get("x", -1.0))
	GameManager.pending_arrival = {}
	show_district(_current_area, arrival_x)
	_update_hud()

## 載入某區街景。spawn_x_frac >= 0 時覆寫無戒水平落點（計程車直達地點用）。
func show_district(area_id: String, spawn_x_frac: float = -1.0) -> void:
	_current_area = area_id
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	district.setup(area, _locs_in(area_id), int(GameManager.player.period), _locked_areas(), spawn_x_frac)
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))

func _locs_in(area_id: String) -> Array:
	var out: Array = []
	for id in _locations:
		var l: Dictionary = _locations[id].duplicate(); l["id"] = id
		if String(l.get("district", "")) == area_id: out.append(l)
	return out

func _locked_areas() -> Dictionary:
	var d: Dictionary = {}
	for aid in _areas:
		var a: Dictionary = _areas[aid]
		d[aid] = a.has("unlock_flag") and not GameManager.get_flag(a.unlock_flag)
	return d

## 快速移動（沿用介面）：設目的區後重載地圖。
func travel_to(area_id: String, _spawn: Vector3 = Vector3.ZERO) -> void:
	GameManager.player.current_area = area_id
	SceneRouter.go_to_map()

func _on_location_entered(id: String) -> void:
	_current_loc = id
	district.visible = false
	interior.open(_locations[id], func(title, actions, _cb): hud.show_action_menu(title, actions, perform_action))

func leave_location() -> void:
	hud.hide_action_menu()
	interior.visible = false
	district.visible = true

func _on_edge_to(area_id: String) -> void:
	travel_to(area_id)

func show_city_map() -> void:
	city.setup(_areas)
	city.open()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_open_main_menu()

func _on_time_advanced(_p: int) -> void:
	_update_hud()
	district.setup(_areas.get(_current_area, {}), _locs_in(_current_area), int(GameManager.player.period), _locked_areas())

# === 以下沿用舊 MapScreen.gd（行為不變；random_encounter 區域變數改名 dist 避免與 district 節點衝突）===

func perform_action(action: String) -> void:
	hud.hide_action_menu()
	GameManager.advance_time(1)
	match action:
		"main_quest":
			MainQuestManager.continue_story()
		"random_encounter":
			var dist: String = _locations[_current_loc].district
			EventBus.random_encounter_triggered.emit(dist)
			SceneRouter.go_to_battle(_pick_enemy(dist))
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
		"shop":
			if not GameManager.get_flag("zheng_ma_shop_unlocked"):
				hud.show_toast("鄭媽的店還沒開")
			else:
				if get_node_or_null("ShopScreen") == null:  # 防重複開店（仿 _open_main_menu 守門）
						var shop_overlay: CanvasLayer = SHOP_SCREEN.new()
						shop_overlay.name = "ShopScreen"
						add_child(shop_overlay)  # ShopScreen 純 .gd CanvasLayer（自設 layer=100 > HUD layer=1，蓋在 HUD 上），用 .new()
		_:
			if action.begins_with("quest_"):
				QuestManager.trigger_action(action, _current_loc)
				hud.show_toast("支線對話尚未製作（Step 7）")
	_update_hud()

func _store_position() -> void:
	GameManager.player.current_area = _current_area

func _pick_enemy(dist: String) -> String:
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	var pool: Array = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if e.get("district", "") != dist:
			continue
		if e.has("time_restriction") and GameManager.player.period not in e.time_restriction:
			continue
		pool.append(id)
	if pool.is_empty():
		return "street_punk"
	return pool[randi() % pool.size()]

func _on_achievement_unlocked(id: String) -> void:
	_toast_achievement(id)
	AchievementSystem.pending_toasts.erase(id)

func _drain_pending_achievements() -> void:
	for id in AchievementSystem.pending_toasts:
		_toast_achievement(id)
	AchievementSystem.pending_toasts.clear()

func _toast_achievement(id: String) -> void:
	var label: String = id
	for a in AchievementSystem.get_all():
		if a.id == id:
			label = String(a.name)
			break
	hud.show_toast("十二因緣 · %s　已證" % label)

func _update_hud() -> void:
	hud.set_time(GameManager.player.day, GameManager.TIME_PERIODS[GameManager.player.period])
	hud.update_stats()

func _open_main_menu() -> void:
	if get_node_or_null("MenuShell") != null:
		return
	if Dialogic.current_timeline != null:
		return
	add_child(MENU_SHELL.instantiate())
