extends Node
## 3D 水墨探索協調者：依 current_area instantiate 區場景到 $World，灑 LocationTrigger，
## 沿用所有後端（perform_action / HUD / 存檔 / 主線 / 商店 / 成就）。

const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")
const SHOP_SCREEN := preload("res://src/ui/menu/ShopScreen.gd")
const LOCATION_TRIGGER := preload("res://src/screens/MapScreen/LocationTrigger.tscn")
const ROAMING_ENEMY := preload("res://src/screens/MapScreen/RoamingEnemy.gd")

## 多功能 NPC：按 E 不跳 ActionMenu，改進對話——NPC 先問話，玩家在 Dialogic 選項裡分流。
## 選項各自 [signal arg="menu_action:<action id>"]，由 _on_dialogic_signal 收到後
## deferred 呼叫 perform_action；「沒事，先離開」選項不帶 signal，對話結束即靜靜收場。
const NPC_ENTRY_TIMELINE: Dictionary = {
	"npc_liaochen": "liaochen_hub",
	"npc_zheng_ma": "zheng_ma_hub",
	"npc_cherry":   "cherry_hub",
	"npc_ah_ming":  "ah_ming_hub",
}

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD

var _areas: Dictionary = {}
var _locations: Dictionary = {}     # 手機計程車目的地（保留，兩用分離）
var _npcs: Dictionary = {}          # 3D 探索的個別互動點（NPC / 店 / 功能）
var _enemies_data: Dictionary = {}  # 各區路上漫遊敵人（人中之龍式）
var _current_area: String = ""
var _current_loc: String = ""
var _current_actions: Array = []
var _broken_zones: Dictionary = {}  # 本次進區已觸發過的破戒氛圍點（防重彈）

func _ready() -> void:
	_areas = JsonLoader.load_json("res://data/areas.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")
	_npcs = JsonLoader.load_json("res://data/map_npcs.json")
	_enemies_data = JsonLoader.load_json("res://data/map_enemies.json")
	_register_interact_action()
	_current_area = String(GameManager.player.get("current_area", "shrine"))
	GameManager.time_advanced.connect(_on_time_advanced)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.quest_location_blocked.connect(_on_quest_location_blocked)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	_drain_pending_achievements()
	_load_area(_current_area)
	_update_hud()

## 載入區環境 + 灑該區觸發點 + 定位玩家 + 切 BGM。
func _load_area(area_id: String) -> void:
	_current_area = area_id
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	for c in world.get_children():
		c.queue_free()
	var env_path: String = String(area.get("environment", ""))
	if not ResourceLoader.exists(env_path):
		push_warning("MapScreen: 區 %s 環境不存在(%s)，fallback ShrineStreet" % [area_id, env_path])
		env_path = "res://src/screens/MapScreen/environments/ShrineStreet.tscn"
	var env: Node = load(env_path).instantiate()
	world.add_child(env)
	_broken_zones.clear()
	_spawn_triggers(env, area_id)
	_spawn_enemies(env, area_id)
	_place_player(area)
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))

## 依 map_npcs.json 灑該區（且已解鎖）的個別互動點（每 NPC / 店 / 功能各一個觸發器）。
## 不按時段過濾觸發點；要時段限定探索再加 available_periods 檢查。
func _spawn_triggers(env: Node, area_id: String) -> void:
	for id in _npcs:
		if String(id).begins_with("_"):
			continue  # 跳過 _schema 說明鍵
		var l: Dictionary = _npcs[id]
		if String(l.get("district", "")) != area_id:
			continue
		if l.has("unlock_flag") and not GameManager.get_flag(l.unlock_flag):
			continue
		var trig: Area3D = LOCATION_TRIGGER.instantiate()
		env.add_child(trig)
		trig.setup(id, l)
		trig.player_entered.connect(_on_trigger_entered.bind(id))
		trig.player_exited.connect(_on_trigger_exited.bind(id))

## 依 map_enemies.json 灑該區的路上漫遊敵人（人中之龍式）。追到玩家→_on_enemy_caught 起遭遇戰。
## 敵人加進 group "roaming_enemy" 供測試/凍結查找。缺模型檔則 RoamingEnemy.setup 內優雅略過。
## 剛打贏的敵人本次載入不重生（消耗 roamer_down_<id> 旗標）→ 戰後回街上不會原地再被同隻抓。
func _spawn_enemies(env: Node, area_id: String) -> void:
	var list: Array = _enemies_data.get(area_id, [])
	for e in list:
		var eid := String(e.get("enemy_id", ""))
		if GameManager.get_flag("roamer_down_" + eid, false):
			GameManager.set_flag("roamer_down_" + eid, false)   # 消耗：下次重進地圖才重生
			continue
		var enemy: Node3D = ROAMING_ENEMY.new()
		enemy.add_to_group("roaming_enemy")
		env.add_child(enemy)
		enemy.setup(e)
		enemy.caught_player.connect(_on_enemy_caught)

## 被漫遊敵人追到：非選單/對話中才進戰鬥（避免蓋在 UI 上）。位置由 go_to_battle 存。
## 掛勝利 hook：打贏後 roamer_down_<id>=true → 回場時該隻不重生（戰敗路徑會清掉 hook，照常重生）。
func _on_enemy_caught(enemy_id: String) -> void:
	if Dialogic.current_timeline != null:
		return
	if get_node_or_null("MenuShell") != null or get_node_or_null("ShopScreen") != null:
		return
	GameManager.set_flag("battle_clear_flag_on_win", "roamer_down_" + enemy_id)
	SceneRouter.go_to_battle(enemy_id)

## 落點優先序：計程車 pending_arrival.loc → 戰後 last_position(同區非原點) → default_spawn。
func _place_player(area: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	player.global_position = _spawn_position(area)

func _spawn_position(area: Dictionary) -> Vector3:
	# 1) 計程車落點：到該地點門口（position_3d 往街頭退一點，避免一生成就觸發）
	if not GameManager.pending_arrival.is_empty() \
			and String(GameManager.pending_arrival.get("area", "")) == _current_area:
		var loc_id: String = String(GameManager.pending_arrival.get("loc", ""))
		GameManager.pending_arrival = {}
		if _locations.has(loc_id):
			var p: Dictionary = _locations[loc_id].get("position_3d", {})
			var r: float = float(_locations[loc_id].get("trigger_radius", 2.5))
			return Vector3(float(p.get("x", 0.0)), 1.2, float(p.get("z", 0.0)) + r + 1.0)
	GameManager.pending_arrival = {}
	# 2) 戰後返回：last_position（travel_to 已把它清成原點 → 快速移動會落 default_spawn）
	var lp: Dictionary = GameManager.player.get("last_position", {})
	var lpv := Vector3(float(lp.get("x", 0.0)), float(lp.get("y", 0.0)), float(lp.get("z", 0.0)))
	if lpv != Vector3.ZERO:
		return lpv
	# 3) 預設落點
	var ds: Dictionary = area.get("default_spawn", {"x": 0.0, "y": 1.2, "z": 6.0})
	return Vector3(float(ds.get("x", 0.0)), float(ds.get("y", 1.2)), float(ds.get("z", 6.0)))

## 進入類動作（場所/設施入口）：提示用「進入」，其餘（NPC對話、賽錢箱等）用「對話」/「參拜」。
const ENTER_ACTIONS: Array = [
	"bowling_minigame", "batting_minigame", "enter_parlor", "beggar_minigame"
]

## 依該點的 action 與是否有 NPC 模型，決定畫面提示動詞（對話 / 進入 / 參拜）。
func _prompt_verb(loc: Dictionary) -> String:
	var actions: Array = loc.get("actions", [])
	if actions.size() == 1 and String(actions[0]) in ENTER_ACTIONS:
		return "進入"
	if actions.size() == 1 and String(actions[0]) == "offering_toss":
		return "參拜"
	if loc.has("npc_model") and String(loc.get("npc_model", "")) != "":
		return "對話"
	return "互動"

## 走近某互動點：顯示提示（不直接跳選單），並在破戒場所自動觸發一次誘惑。
func _on_trigger_entered(id: String) -> void:
	_current_loc = id
	var loc: Dictionary = _npcs.get(id, {})
	_current_actions = loc.get("actions", [])
	var verb := _prompt_verb(loc)
	hud.show_prompt("%s%s" % [verb, String(loc.get("name", id))])
	if loc.has("ambient_break") and not _broken_zones.has(id):
		_broken_zones[id] = true
		BreakVowSystem.try_trigger(String(loc.ambient_break))

func _on_trigger_exited(id: String) -> void:
	if _current_loc == id:
		_current_loc = ""
		_current_actions = []
		hud.hide_prompt()
		hud.hide_action_menu()

## 快速移動（手機移動 app 呼叫）：設目的區、清舊位(快速移動落區中心)、重載。
func travel_to(area_id: String) -> void:
	GameManager.player.current_area = area_id
	GameManager.player.last_position = {"x": 0.0, "y": 0.0, "z": 0.0}
	SceneRouter.go_to_map()

## 鐵叔對話 timeline（依阿瑞斯是否已超渡分歧）；抽成函式供測試。
func armory_npc_timeline() -> String:
	return "armory_worker_freed" if GameManager.get_flag("ares_purified") else "armory_worker_locked"

## SceneRouter 戰前呼叫，存玩家位置供戰後返回。
func get_player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_open_main_menu()
	elif event.is_action_pressed("interact"):
		_interact()

## 走近互動點後按 E：只 1 項＝直接執行；多項的多功能 NPC＝進對話讓 NPC 問話、玩家選項分流。
func _interact() -> void:
	if _current_loc == "" or _current_actions.is_empty():
		return
	if hud.action_menu.visible or Dialogic.current_timeline != null:
		return
	if get_node_or_null("MenuShell") != null or get_node_or_null("ShopScreen") != null:
		return
	if _current_actions.size() == 1:
		perform_action(String(_current_actions[0]))
	elif NPC_ENTRY_TIMELINE.has(_current_loc):
		Dialogic.start(String(NPC_ENTRY_TIMELINE[_current_loc]))
	else:
		# 保底：未建對話分流的多動作點（理論上不該再有），沿用舊選單避免卡死。
		var loc: Dictionary = _npcs.get(_current_loc, {})
		hud.show_action_menu(String(loc.get("name", _current_loc)), _current_actions, perform_action)

## Dialogic 選項用 [signal arg="menu_action:<action>"] 把選到的功能傳出來；
## deferred 呼叫避免在 Dialogic 事件處理當下就重入 perform_action（可能立刻再 Dialogic.start）。
func _on_dialogic_signal(arg: Variant) -> void:
	if typeof(arg) != TYPE_STRING:
		return
	var s := (arg as String)
	if not s.begins_with("menu_action:"):
		return
	var action := s.substr("menu_action:".length()).strip_edges()
	if action != "":
		call_deferred("perform_action", action)

## 執行期註冊「interact」動作（E 鍵），避免動 project.godot 的 InputEvent 序列化格式。
func _register_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)

func _on_time_advanced(_p: int) -> void:
	_update_hud()

# === 動作分派（沿用舊版，新增 armory_npc；random_encounter 用 _current_loc）===

func perform_action(action: String) -> void:
	hud.hide_action_menu()
	GameManager.advance_time(1)
	match action:
		"main_quest":
			MainQuestManager.continue_story()
		"random_encounter":
			var dist: String = _current_area
			EventBus.random_encounter_triggered.emit(dist)
			SceneRouter.go_to_battle(_pick_enemy(dist))
		"cherry_dialogue":
			if ResourceLoader.exists("res://dialogue/cherry_first_meeting.dtl"):
				Dialogic.start("cherry_first_meeting")
			else:
				hud.show_toast("Cherry 對話尚未製作")
		"armory_npc":
			var tl := armory_npc_timeline()
			if tl == "armory_worker_freed" and not GameManager.get_flag("armory_worker_thanked"):
				GameManager.add_item("heal_salve", 1)
				GameManager.set_flag("armory_worker_thanked", true)
			if ResourceLoader.exists("res://dialogue/%s.dtl" % tl):
				Dialogic.start(tl)
		"food_break_trigger":
			BreakVowSystem.try_trigger("food")
		"greed_break_trigger":
			BreakVowSystem.try_trigger("greed")
		"lust_break_trigger":
			BreakVowSystem.try_trigger("lust")
		"beggar_minigame":
			SceneRouter.go_to_minigame("beggar_challenge")
		"offering_toss":
			SceneRouter.go_to_minigame("offering_toss")
		"wooden_fish_replay":
			# 常駐入口：ah_ming 支線完成後才開放，無 quest context（休閒場，win merit+1）。
			if not GameManager.get_flag("ah_ming_saved"):
				hud.show_toast("翔太還在忙，等他闖過這關再說")
			else:
				SceneRouter.go_to_minigame("wooden_fish_rhythm")
		"batting_minigame":
			SceneRouter.go_to_minigame("batting")
		"bowling_minigame":
			SceneRouter.go_to_minigame("bowling")
		"enter_parlor":
			# 地下遊藝場＝獨立 3D 房間（非 area）。先存街上位置，出來時
			# UndergroundParlor 走 go_to_map() → 依 last_position 落回這裡。
			_store_position()
			SceneRouter.go_to_scene("res://src/screens/MapScreen/environments/UndergroundParlor.tscn")
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
				if get_node_or_null("ShopScreen") == null:
					var shop_overlay: CanvasLayer = SHOP_SCREEN.new()
					shop_overlay.name = "ShopScreen"
					add_child(shop_overlay)
		_:
			if action.begins_with("quest_"):
				var qid := action.replace("quest_", "")
				if QuestManager.is_quest_actionable(qid):
					QuestManager.trigger_action(action, _current_loc)
				else:
					hud.show_toast("這個人現在沒有事找你")
	_update_hud()

func _store_position() -> void:
	GameManager.player.current_area = _current_area
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var p := player.global_position
		GameManager.player.last_position = {"x": p.x, "y": p.y, "z": p.z}

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

## 主線 stage 要求人在對的地點才能繼續（見 MainQuestManager.stage_location_passed）；
## 中止後玩家仍在地圖，用既有 toast 告知去哪裡，不新造 UI。
func _on_quest_location_blocked(hint: String) -> void:
	hud.show_toast(hint)

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
