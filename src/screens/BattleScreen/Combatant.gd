class_name Combatant
extends RefCounted

## 戰鬥單位資料：玩家與敵人共用（GDD 7.1）

signal hp_changed(current: int, max_hp: int)
signal down_changed(is_down: bool)
signal buff_changed()
signal died

var id: String = ""
var base_id: String = ""   # 敵人原始 id（不含 spawn 後綴）→ 弱點探知記錄用（跨戰鬥同型敵共享）
var display_name: String = ""
var max_hp: int = 100
var current_hp: int = 100
var attack: int = 50
var defense: int = 0
var speed: int = 10          # 行動佇列排序用（第二期）：敵暫值＝10＋level×2，玩家基礎 15＋盤加成
var level: int = 1
var karma: int = 0
var weaknesses: Array = []
var resistances: Array = []
var skills: Array = []
var skill_defs: Dictionary = {}
var ai_pattern: String = "random"
var gold_reward: int = 0
var is_boss: bool = false
var is_player: bool = false
var is_downed: bool = false
var summoned_backup: bool = false
var chaos_target: Combatant = null
var buffs: Dictionary = {}  # buff_name → {"value": float, "duration": int}
var is_guarding: bool = false      # 本回合選了「防禦」指令 → 普通減傷 50%（第二期）
var perfect_guard_ready: bool = false  # 完美格擋判定窗有效期間為 true（BattleManager 控制）
var portrait_path: String = ""        # 已解析的立繪 res:// 路徑（空＝無立繪）
var portrait_moods: Dictionary = {}   # mood_key → 已解析 res:// 路徑（Boss 動態表情）

static func from_enemy(enemy_id: String, data: Dictionary, suffix: String = "") -> Combatant:
	var c := Combatant.new()
	c.id = enemy_id + suffix
	c.base_id = enemy_id
	c.display_name = data.get("name", enemy_id)
	c.max_hp = data.get("max_hp", 100)
	c.current_hp = c.max_hp
	c.attack = data.get("attack", 30)
	c.defense = data.get("defense", 0)
	c.level = data.get("level", 1)
	c.speed = data.get("speed", 10 + c.level * 2)  # enemies.json 有 speed 用之，否則暫值公式
	c.karma = data.get("karma", c.level * 10)
	c.weaknesses = data.get("weaknesses", [])
	c.resistances = data.get("resistances", [])
	c.skills = data.get("skills", [])
	c.skill_defs = data.get("skill_defs", {})
	c.ai_pattern = data.get("ai_pattern", "random")
	c.gold_reward = data.get("gold_reward", 0)
	c.is_boss = data.get("is_boss", false)
	c.portrait_path = BattleArt.resolve_portrait_path(String(data.get("portrait", "")))
	for k in data.get("portrait_moods", {}):
		var rp: String = BattleArt.resolve_portrait_path(String(data["portrait_moods"][k]))
		if rp != "":
			c.portrait_moods[k] = rp
	return c

static func from_player() -> Combatant:
	var c := Combatant.new()
	var p: Dictionary = GameManager.player
	c.id = "player"
	c.display_name = p.name
	# 基礎值 HP500／攻100／防10／敏15 不變，成長全靠修行盤（第三期）：bonus 讀 board_unlocked 計算。
	var bonus: Dictionary = CultivationBoard.compute_bonus()
	c.max_hp = p.max_hp + int(bonus.get("hp", 0))
	c.current_hp = mini(p.current_hp, c.max_hp)
	c.attack = 100 + int(bonus.get("atk", 0))
	c.defense = 10 + int(bonus.get("def", 0))
	c.speed = 15 + int(bonus.get("spd", 0))
	c.karma = p.karma
	c.is_player = true
	return c

func take_damage(v: int) -> void:
	current_hp = clampi(current_hp - v, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()

func heal(v: int) -> void:
	current_hp = clampi(current_hp + v, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0

func set_down(v: bool) -> void:
	if is_downed == v:
		return
	is_downed = v
	down_changed.emit(v)

func add_buff(buff_name: String, value: float, duration: int) -> void:
	buffs[buff_name] = {"value": value, "duration": duration}
	buff_changed.emit()

func has_buff(buff_name: String) -> bool:
	return buffs.has(buff_name)

func buff_value(buff_name: String, default: float = 0.0) -> float:
	return buffs.get(buff_name, {}).get("value", default)

func consume_buff(buff_name: String) -> void:
	buffs.erase(buff_name)
	buff_changed.emit()

func tick_buffs() -> void:
	for key in buffs.keys():
		buffs[key].duration -= 1
		if buffs[key].duration <= 0:
			buffs.erase(key)
	buff_changed.emit()
