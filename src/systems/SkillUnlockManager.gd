extends Node

## 技能解鎖綁定玩家行為（GDD 八・五）。
## 重構（2026-06-14）：條件改為資料驅動 UNLOCK_TABLE，單一真相源同時供
## ① check_unlocks() 判定解鎖 ② get_unlock_state() 給經書技能頁顯示「解鎖進度」。
##
## kind：
##   initial  — 開局即解鎖（自動學）。
##   story    — 劇情當場親授（羅漢拳，c1_intel signal 直給），不入習得。
##   flag     — get_flag(flag) 為真即解鎖（旗標型，如破戒/瀕死/支線旗標）。
##   quest    — quest 在 completed_quests 即解鎖。
##   behavior — get_flag(flag,0) >= target 即解鎖，並回報 current/target 進度。
##   heat     — 滿值處決技，不經成長解鎖、不入 skills_unlocked（戰鬥內滿值發動）。
const UNLOCK_TABLE := {
	# 苦行僧
	"basic_punch":     {"kind": "initial"},
	"arhat_strike":    {"kind": "story"},
	"vajra_glare":     {"kind": "flag", "flag": "ah_ming_saved"},
	"ascetic_temper":  {"kind": "behavior", "flag": "weakness_hit_count", "target": 10},
	"iron_shirt":      {"kind": "flag", "flag": "broke_any_vow"},
	"sacrifice_strike":{"kind": "behavior", "flag": "kill_count", "target": 20},
	"tathagata_palm":  {"kind": "heat"},
	# 念經僧
	"wooden_fish":     {"kind": "initial"},
	"sound_wave":      {"kind": "quest", "quest": "ah_zhong"},
	"great_compassion_shield": {"kind": "quest", "quest": "zheng_ma"},
	"requiem":         {"kind": "flag", "flag": "near_death_triggered"},
	"karma_rebound":   {"kind": "flag", "flag": "karma_maxed_once"},
	"sutra_seal":      {"kind": "behavior", "flag": "cherry_affection", "target": 50},
	"diamond_sutra":   {"kind": "heat"},
	# 化緣僧
	"broken_bowl_beg": {"kind": "behavior", "flag": "kill_count", "target": 6},
	"lions_roar":      {"kind": "quest", "quest": "lao_wang"},
	"self_harm":       {"kind": "behavior", "flag": "weakness_hit_count", "target": 5},
	"underdog":        {"kind": "flag", "flag": "david_listened"},
	"rolling_taunt":   {"kind": "behavior", "flag": "karma_skill_count", "target": 10},
	"alms_wave":       {"kind": "quest", "quest": "grandma"},
	"thousand_hands":  {"kind": "heat"},
}

const LEARNABLE_KINDS := ["flag", "quest", "behavior"]

var _skills: Dictionary = {}
var _skill_names: Dictionary = {}
var _announced_learnable: Dictionary = {}   # 已 toast 過「可學」的 skill_id（runtime 去重）

func _ready() -> void:
	_skills = JsonLoader.load_json("res://data/skills.json")
	for id in _skills:
		_skill_names[id] = _skills[id].get("name", id)
	check_unlocks(false)   # 建立 initial、把當下已達成者標為已通知（不洗 toast）

## 學習狀態（給技能頁）：{learned, learnable, condition_met, kind, label, current, target}。
## learned＝已進 skills_unlocked（戰鬥能用、計入 gate）。
## condition_met＝解鎖條件達成（initial/heat 恆 true；story＝已被劇情授予）。
## learnable＝condition_met 且未學 且屬須習得類（flag/quest/behavior）。
func get_unlock_state(skill_id: String) -> Dictionary:
	var e: Dictionary = UNLOCK_TABLE.get(skill_id, {"kind": "initial"})
	var kind: String = e.get("kind", "initial")
	var label: String = _skills.get(skill_id, {}).get("unlock_condition", "")
	var learned: bool = skill_id in GameManager.player.skills_unlocked
	var condition_met: bool = false
	var current: int = 0
	var target: int = 0
	match kind:
		"initial":
			condition_met = true
		"heat":
			condition_met = true
			if label == "":
				label = "滿值發動"
		"story":
			condition_met = learned
		"flag":
			condition_met = bool(GameManager.get_flag(e.flag))
		"quest":
			condition_met = e.quest in GameManager.player.completed_quests
		"behavior":
			target = int(e.target)
			current = int(GameManager.get_flag(e.flag, 0))
			condition_met = current >= target
	var learnable: bool = condition_met and not learned and kind in LEARNABLE_KINDS
	return {
		"learned": learned,
		"learnable": learnable,
		"condition_met": condition_met,
		"kind": kind,
		"label": label,
		"current": current,
		"target": target,
	}

## 玩家在經書點「習得」：驗證可學 → 進 skills_unlocked。回傳是否成功。
func learn_skill(skill_id: String) -> bool:
	if skill_id in GameManager.player.skills_unlocked:
		return false
	if not get_unlock_state(skill_id).learnable:
		return false
	GameManager.player.skills_unlocked.append(skill_id)
	_notify_learned(skill_id)
	return true

## 目前可學（condition_met 且未學、屬須習得類）的招清單。
func learnable_skills() -> Array:
	var out: Array = []
	for skill_id in UNLOCK_TABLE:
		if get_unlock_state(skill_id).learnable:
			out.append(skill_id)
	return out

## 劇情/系統直接授予（了塵傳羅漢拳、未來劇情招）：進池 + 報「已學」toast。
## 防呆：skills.json 不存在的招不授予（擋鬼招灌 gate）。
func grant_skill(skill_id: String) -> bool:
	if not _skills.has(skill_id):
		push_warning("SkillUnlockManager: 嘗試授予不存在的技能 %s" % skill_id)
		return false
	if skill_id in GameManager.player.skills_unlocked:
		return false
	GameManager.player.skills_unlocked.append(skill_id)
	_notify_learned(skill_id)
	return true

## 掃表：initial 自動學；flag/quest/behavior 條件達成只標「可學」（不入池）並 toast；
## story/heat 跳過。announce=false（_ready/載入）只建立狀態不洗 toast。
func check_unlocks(announce: bool = true) -> void:
	for skill_id in UNLOCK_TABLE:
		var kind: String = UNLOCK_TABLE[skill_id].get("kind", "initial")
		if kind == "initial":
			if skill_id not in GameManager.player.skills_unlocked:
				GameManager.player.skills_unlocked.append(skill_id)
			continue
		if kind == "story" or kind == "heat":
			continue
		if skill_id in GameManager.player.skills_unlocked:
			continue
		if not get_unlock_state(skill_id).condition_met:
			continue
		# 條件達成、未學 → 可學。本輪新可學才 toast（去重）。
		if skill_id in _announced_learnable:
			continue
		_announced_learnable[skill_id] = true
		if announce:
			_notify_learnable(skill_id)

## 三職修為（給經書狀態頁三角雷達）：每職 {unlocked, total}，
## 只計可習得技能（不含滿值處決技 heat）。
func get_job_mastery() -> Dictionary:
	var out := {
		"ascetic": {"unlocked": 0, "total": 0},
		"chanter": {"unlocked": 0, "total": 0},
		"beggar":  {"unlocked": 0, "total": 0},
	}
	for skill_id in _skills:
		if UNLOCK_TABLE.get(skill_id, {}).get("kind", "initial") == "heat":
			continue
		var job: String = _skills[skill_id].get("job", "")
		if not out.has(job):
			continue
		out[job].total += 1
		if skill_id in GameManager.player.skills_unlocked:
			out[job].unlocked += 1
	return out

## 滿值處決技 id 清單（三職各一，狀態頁恆視為可用）。
func get_heat_skill_ids() -> Array:
	var out: Array = []
	for skill_id in UNLOCK_TABLE:
		if UNLOCK_TABLE[skill_id].kind == "heat":
			out.append(skill_id)
	return out

func _notify_learnable(skill_id: String) -> void:
	EventBus.skill_learnable.emit(_skill_names.get(skill_id, skill_id))

func _notify_learned(skill_id: String) -> void:
	EventBus.skill_unlocked.emit(_skill_names.get(skill_id, skill_id))
