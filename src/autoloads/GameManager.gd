extends Node

signal stat_changed(key: String, value: Variant)
signal time_advanced(new_period: int)
signal job_changed(new_job: String)
signal flag_changed(key: String, value: Variant)

const MAX_MERIT: int = 100
const MAX_KARMA: int = 100
const MAX_HP:    int = 500
const TIME_PERIODS = ["上午", "下午", "傍晚", "深夜"]

var player: Dictionary = {
	"name": "無戒",
	"max_hp": MAX_HP, "current_hp": MAX_HP,
	"merit": 0, "karma": 0, "gold": 1000,
	"job": "ascetic",
	"skills_unlocked": ["basic_punch", "wooden_fish"],
	"day": 1, "period": 0,
	"flags": {},
	"completed_quests": [],
	"active_quests": {},
	"last_position": {"x": 0.0, "y": 0.0, "z": 0.0},
	"current_area": "shrine",
	"inventory": {},
	# 戰鬥改版新鍵（舊存檔缺鍵→load_game 保留預設，不炸）
	"daoxing": 0,                 # 修行盤成長貨幣（第二期勝利發放，第三期消費）
	"weakness_intel": {},         # enemy_id → [已探知的弱點屬性]（第一期，跨戰鬥保留）
	"board_unlocked": ["core"]    # 修行盤已解鎖節點（第三期接點）
}

## 計程車落點暫存：{area, x}。MapScreen 載入時讀一次後清空。不寫進 player、不存檔。
var pending_arrival: Dictionary = {}

## 時段推進暫存：戰鬥（勝/敗）或小遊戲「完成」（非中途放棄）結束時設 true，
## 由 SceneRouter.consume_period_advance() 在回到地圖/遊藝場後消費（播字卡＋真正 advance_time）。
## 純執行期旗標，不進 player dict、不存檔。
var pending_period_advance: bool = false

## 無戒對話立繪依職業切換：對話 .dtl 一律寫 `Wujie (calm)` 等(不帶職)，
## 由本機制在每段對話開始時把 Wujie 的 4 表情 image 覆寫成「當前職業」的 bust
## (苦行 ascetic / 誦經 chanter / 化緣 beggar)→ 零 .dtl 改、零 addon 改。
const WUJIE_DCH := "res://dialogue/Wujie.dch"
const WUJIE_MOODS := ["calm", "angry", "happy", "surprised"]
## 常駐持有 Wujie 角色資源：Dialogic 用 load() 取角色(有快取)，但若沒人持有強參考，
## 我們 mutate 過的實例會被釋放、下次 load 重讀磁碟得回原圖。持有它 → 快取那份長存、
## Dialogic load() 拿到的就是我們 mutate 過的同一份。
var _wujie_char: Resource = load(WUJIE_DCH)

const DIALOGUE_HISTORY_PANEL := preload("res://src/ui/DialogueHistoryPanel.gd")

## 對話回想 log 面板：常駐掛在 root 下，跨場景可用（Tab 開關，見 DialogueHistoryPanel.gd）。
var dialogue_history: CanvasLayer

func _ready() -> void:
	# 對話橋接：timeline 內 [signal arg="type:value"] → 改動遊戲狀態。
	# 慣例 type: flag(設旗標true) / affection(累加 cherry_affection) / merit / karma / gold。
	Dialogic.signal_event.connect(_on_dialogic_signal)
	# 每段對話開始 → 依玩家職業套無戒立繪。
	Dialogic.timeline_started.connect(_apply_wujie_job_portraits)
	# 對話回想 log：建一次常駐 overlay，掛在 root 下（不依賴特定畫面）。
	_setup_dialogue_history()

func _setup_dialogue_history() -> void:
	if is_instance_valid(dialogue_history):
		return
	dialogue_history = DIALOGUE_HISTORY_PANEL.new()
	dialogue_history.name = "DialogueHistoryPanel"
	get_tree().root.add_child.call_deferred(dialogue_history)

## 把 Wujie 角色資源的 4 表情立繪換成當前職業的 bust。Dialogic 以快取資源載入
## "Wujie" → 改的就是它實際用的那份；image 用 var_to_str 格式(同 .dch 存法)。
func _apply_wujie_job_portraits() -> void:
	var job: String = "ascetic"
	if player.has("job") and player["job"] in ["ascetic", "chanter", "beggar"]:
		job = player["job"]
	if _wujie_char == null:
		_wujie_char = load(WUJIE_DCH)
	if _wujie_char == null:
		return
	for mood in WUJIE_MOODS:
		if _wujie_char.portraits.has(mood):
			var path := "res://assets/2d/portraits/wujie/bust/wujie_%s_%s.png" % [job, mood]
			_wujie_char.portraits[mood]["export_overrides"]["image"] = var_to_str(path)

func _on_dialogic_signal(arg: Variant) -> void:
	if typeof(arg) != TYPE_STRING:
		return
	var parts: PackedStringArray = (arg as String).split(":")
	if parts.size() < 2:
		return
	var key: String = parts[0].strip_edges()
	var val: String = parts[1].strip_edges()
	match key:
		"flag":
			set_flag(val, true)
		"affection":
			set_flag("cherry_affection", int(get_flag("cherry_affection", 0)) + int(val))
		"merit":
			add_merit(int(val))
		"karma":
			add_karma(int(val))
		"gold":
			add_gold(int(val))
		"skill":
			SkillUnlockManager.grant_skill(val)
		"hp_max":
			player.max_hp += int(val)
			stat_changed.emit("max_hp", player.max_hp)
		"menu_action":
			pass  # 街景多功能 NPC 對話內選單分流，由 MapScreen._on_dialogic_signal 處理，這裡不重複警告。
		_:
			push_warning("GameManager: 未知的對話訊號 %s" % arg)

func advance_time(steps: int = 1) -> void:
	player.period += steps
	if player.period >= TIME_PERIODS.size():
		player.period = 0
		player.day += 1
		add_merit(5)
		EventBus.new_day_started.emit(player.day)
		SaveManager.save_game()
	time_advanced.emit(player.period)

func add_merit(v: int) -> void:
	player.merit = clampi(player.merit + v, 0, MAX_MERIT)
	stat_changed.emit("merit", player.merit)
	if player.merit >= MAX_MERIT:
		EventBus.merit_maxed.emit()
	SkillUnlockManager.check_unlocks()

func add_karma(v: int) -> void:
	player.karma = clampi(player.karma + v, 0, MAX_KARMA)
	stat_changed.emit("karma", player.karma)
	if player.karma >= MAX_KARMA:
		set_flag("karma_maxed_once", true)
		EventBus.karma_maxed.emit()
	SkillUnlockManager.check_unlocks()

func take_damage(v: int) -> void:
	player.current_hp = clampi(player.current_hp - v, 0, player.max_hp)
	stat_changed.emit("current_hp", player.current_hp)
	if player.current_hp <= 0:
		EventBus.player_died.emit()
	elif player.current_hp < player.max_hp * 0.2:
		set_flag("near_death_triggered", true)
		SkillUnlockManager.check_unlocks()

func heal(v: int) -> void:
	player.current_hp = clampi(player.current_hp + v, 0, player.max_hp)
	stat_changed.emit("current_hp", player.current_hp)

func spend_gold(v: int) -> bool:
	if player.gold < v:
		return false
	player.gold -= v
	stat_changed.emit("gold", player.gold)
	return true

func add_gold(v: int) -> void:
	player.gold += v
	stat_changed.emit("gold", player.gold)

# ─── 道行（修行盤貨幣）／弱點探知（第一/二期）────────────────────
## 舊存檔缺鍵防呆：存取前確保鍵存在（同 _ensure_inventory 模式）。
func _ensure_battle_keys() -> void:
	if not player.has("daoxing"):
		player["daoxing"] = 0
	if not player.has("weakness_intel") or typeof(player.weakness_intel) != TYPE_DICTIONARY:
		player["weakness_intel"] = {}
	if not player.has("board_unlocked") or typeof(player.board_unlocked) != TYPE_ARRAY:
		player["board_unlocked"] = ["core"]

func add_daoxing(v: int) -> void:
	_ensure_battle_keys()
	player.daoxing = maxi(0, int(player.daoxing) + v)
	stat_changed.emit("daoxing", player.daoxing)

## 命中某敵某屬性 → 記錄探知（跨戰鬥保留、進存檔）。回傳是否為「新探知」。
func record_weakness_intel(enemy_id: String, element: String) -> bool:
	_ensure_battle_keys()
	var known: Array = player.weakness_intel.get(enemy_id, [])
	if element in known:
		return false
	known.append(element)
	player.weakness_intel[enemy_id] = known
	stat_changed.emit("weakness_intel", player.weakness_intel)
	return true

## 查某敵某屬性是否已探知（EnemyPanel 決定顯示「弱 淨」或「弱 ？」）。
func knows_weakness(enemy_id: String, element: String) -> bool:
	_ensure_battle_keys()
	return element in player.weakness_intel.get(enemy_id, [])

# ─── 背包 / 道具 ───────────────────────────────────────
## 舊存檔可能無 inventory 鍵 → 存取前確保存在（belt-and-suspenders；
## load_game 以預設 player 為底合併，預設已含 inventory:{}，此處再防呆）。
func _ensure_inventory() -> void:
	if not player.has("inventory") or typeof(player.inventory) != TYPE_DICTIONARY:
		player["inventory"] = {}

func item_count(id: String) -> int:
	_ensure_inventory()
	return int(player.inventory.get(id, 0))  # JSON 讀回是 float，int() 夾正

func add_item(id: String, n: int = 1) -> void:
	_ensure_inventory()
	player.inventory[id] = item_count(id) + n
	stat_changed.emit("inventory", player.inventory)

func consume_item(id: String) -> bool:
	_ensure_inventory()
	var c: int = item_count(id)
	if c <= 0:
		return false
	if c <= 1:
		player.inventory.erase(id)
	else:
		player.inventory[id] = c - 1
	stat_changed.emit("inventory", player.inventory)
	return true

func switch_job(job: String) -> void:
	if job not in ["ascetic", "chanter", "beggar"]:
		return
	player.job = job
	job_changed.emit(job)

func set_flag(key: String, val: Variant) -> void:
	var changed: bool = not player.flags.has(key) or player.flags[key] != val
	player.flags[key] = val
	if changed:
		flag_changed.emit(key, val)  # AchievementSystem 監聽：旗標即解鎖條件

func get_flag(key: String, default: Variant = false) -> Variant:
	return player.flags.get(key, default)

## 新遊戲：重置玩家狀態。本輪起始＝西門町（看真街）；破廟真環境做好後可改回 hub。
func new_game() -> void:
	player = {
		"name": "無戒",
		"max_hp": MAX_HP, "current_hp": MAX_HP,
		"merit": 0, "karma": 0, "gold": 1000,
		"job": "ascetic",
		"skills_unlocked": ["basic_punch", "wooden_fish"],
		"day": 1, "period": 0,
		"flags": {},
		"completed_quests": [],
		"active_quests": {},
		"last_position": {"x": 0.0, "y": 1.2, "z": 6.0},
		"current_area": "shrine",
		"inventory": {},
		"daoxing": 0,
		"weakness_intel": {},
		"board_unlocked": ["core"]
	}
	if is_instance_valid(dialogue_history):
		dialogue_history.clear_log()
