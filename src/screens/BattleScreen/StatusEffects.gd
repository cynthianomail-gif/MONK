extends Node

## 12 種狀態異常（GDD 7.3）
## chaos / burn / stun / seal / slow / fear / poison / weaken
## taunt / down / golden_body / brahma_resonance

signal status_applied(target_id: String, status_type: String)
signal status_damage(target_id: String, amount: int, status_type: String)

const NEGATIVE: Array = ["chaos", "burn", "stun", "seal", "slow", "fear", "poison", "weaken", "taunt"]

var _active: Dictionary = {}  # target_id → Array[{type, duration}]

func apply(status_type: String, target: Combatant, duration: int) -> void:
	if status_type == "fear" and target.is_boss:
		return  # Boss 免疫恐懼
	if not _active.has(target.id):
		_active[target.id] = []
	_active[target.id].append({"type": status_type, "duration": duration})
	status_applied.emit(target.id, status_type)

## 回傳 false 表示本回合跳過行動
func process_turn_start(combatant: Combatant) -> bool:
	var effects: Array = _active.get(combatant.id, [])
	for eff in effects:
		match eff.type:
			"stun":
				eff.duration -= 1
				return false
			"fear":
				if randf() < 0.5:
					return false
			"slow":
				eff.duration -= 1
				return false
			"chaos":
				combatant.chaos_target = null  # BattleManager 決定亂打對象
	return true

func process_turn_end(combatant: Combatant) -> void:
	var effects: Array = _active.get(combatant.id, [])
	for eff in effects.duplicate():
		match eff.type:
			"burn":
				combatant.take_damage(15)
				status_damage.emit(combatant.id, 15, "burn")
			"poison":
				var stacks: int = effects.filter(func(e): return e.type == "poison").size()
				combatant.take_damage(10 * stacks)
				status_damage.emit(combatant.id, 10 * stacks, "poison")
		eff.duration -= 1
		if eff.duration <= 0:
			effects.erase(eff)

func clear_negative(combatant: Combatant) -> void:
	_active[combatant.id] = _active.get(combatant.id, []).filter(
		func(e): return e.type not in NEGATIVE
	)

func has_status(combatant: Combatant, status: String) -> bool:
	return _active.get(combatant.id, []).any(func(e): return e.type == status)

func active_statuses(combatant: Combatant) -> Array:
	var result: Array = []
	for eff in _active.get(combatant.id, []):
		if eff.type not in result:
			result.append(eff.type)
	return result

func reset() -> void:
	_active.clear()
