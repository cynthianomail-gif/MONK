extends Node

## 技能解鎖完全綁定玩家行為旗標，不綁天數（GDD 八・五）

var _conditions: Dictionary = {}
var _skill_names: Dictionary = {}

func _ready() -> void:
	var skills: Dictionary = JsonLoader.load_json("res://data/skills.json")
	for id in skills:
		_skill_names[id] = skills[id].get("name", id)
	_conditions = {
		# 苦行僧
		"arhat_strike":    func() -> bool: return true,
		"vajra_glare":     func() -> bool: return GameManager.get_flag("ah_ming_saved"),
		"ascetic_temper":  func() -> bool: return GameManager.get_flag("weakness_hit_count", 0) >= 10,
		"iron_shirt":      func() -> bool: return GameManager.get_flag("broke_any_vow"),
		"sacrifice_strike": func() -> bool: return GameManager.get_flag("kill_count", 0) >= 20,
		# 念經僧
		"sound_wave":      func() -> bool: return true,
		"great_compassion_shield": func() -> bool: return "zheng_ma" in GameManager.player.completed_quests,
		"requiem":         func() -> bool: return GameManager.get_flag("near_death_triggered"),
		"karma_rebound":   func() -> bool: return GameManager.get_flag("karma_maxed_once"),
		"sutra_seal":      func() -> bool: return GameManager.get_flag("cherry_affection", 0) >= 50,
		# 化緣僧
		"broken_bowl_beg": func() -> bool: return true,
		"lions_roar":      func() -> bool: return true,
		"self_harm":       func() -> bool: return true,
		"underdog":        func() -> bool: return GameManager.get_flag("david_listened"),
		"rolling_taunt":   func() -> bool: return GameManager.get_flag("karma_skill_count", 0) >= 10,
		"alms_wave":       func() -> bool: return "grandma" in GameManager.player.completed_quests,
	}
	check_unlocks()

func check_unlocks() -> void:
	if _conditions.is_empty():
		return
	for skill_id in _conditions:
		if skill_id in GameManager.player.skills_unlocked:
			continue
		if _conditions[skill_id].call():
			GameManager.player.skills_unlocked.append(skill_id)
			_notify_unlock(skill_id)

func _notify_unlock(skill_id: String) -> void:
	var skill_name: String = _skill_names.get(skill_id, skill_id)
	EventBus.skill_unlocked.emit(skill_name)
