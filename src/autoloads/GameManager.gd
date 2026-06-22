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
	"inventory": {}
}

## 計程車落點暫存：{area, x}。MapScreen 載入時讀一次後清空。不寫進 player、不存檔。
var pending_arrival: Dictionary = {}

func _ready() -> void:
	# 對話橋接：timeline 內 [signal arg="type:value"] → 改動遊戲狀態。
	# 慣例 type: flag(設旗標true) / affection(累加 cherry_affection) / merit / karma / gold。
	Dialogic.signal_event.connect(_on_dialogic_signal)

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
		"vow":
			# 由對話分支觸發破戒（例：Cherry 逃跑→色戒）。
			BreakVowSystem.try_trigger(val)
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
		"inventory": {}
	}
