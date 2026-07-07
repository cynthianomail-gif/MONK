extends Node

## 11 種狀態異常
## chaos / burn / stun / seal / slow / fear / poison / weaken
## taunt / down / golden_body

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

## 回傳 false 表示本回合跳過行動。
## stun/slow 的 duration 只在這裡消耗（跳過幾次行動就持續幾點）——
## 不能在 process_turn_end 再扣：受害者若在中狀態前已行動，回合結算會把
## duration 1 直接清成 0，暈眩/遲緩對「比施術者快的目標」永遠不生效。
func process_turn_start(combatant: Combatant) -> bool:
	var effects: Array = _active.get(combatant.id, [])
	for eff in effects.duplicate():
		match eff.type:
			"stun", "slow":
				eff.duration -= 1
				if eff.duration <= 0:
					effects.erase(eff)
				return false
			"fear":
				if randf() < 0.5:
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
		if eff.type in ["stun", "slow"]:
			continue  # 由 process_turn_start 消耗
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
