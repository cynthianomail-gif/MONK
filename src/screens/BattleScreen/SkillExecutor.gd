extends Node

## 技能執行與傷害公式（GDD 7.2）
## base = skill.power × (atk / 100)
## weakness_mult: 弱點 ×2.0，一般 ×1.0，抗性 ×0.5
## crit: 10% 機率 ×1.5
## 最終 = base × weakness_mult × crit_mult × buff_mult

signal skill_played(skill_name: String, caster_id: String, hit_weakness: bool, is_crit: bool)
signal damage_dealt(target_id: String, amount: int, damage_type: String)
signal gold_stolen(amount: int)

@onready var status: Node = $StatusEffects

var _skills: Dictionary = {}

func _ready() -> void:
	_skills = JsonLoader.load_json("res://data/skills.json")

func get_skill(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {})

func execute(skill_id: String, caster: Combatant, target: Combatant, all_enemies: Array) -> Dictionary:
	var sk: Dictionary = _skills.get(skill_id, {})
	if sk.is_empty():
		return {"error": "unknown_skill"}
	var result: Dictionary = {"target_id": target.id, "hit_weakness": false, "is_crit": false}

	if not _pay_cost(sk, caster):
		return {"error": "cost_failed"}

	var dtype: String = sk.get("damage_type", "physical")

	# 傷害類技能
	if dtype != "support" and dtype != "passive":
		var targets: Array = _resolve_targets(sk, target, all_enemies)
		for t in targets:
			var r := _deal_damage(sk, caster, t)
			if r.hit_weakness:
				result.hit_weakness = true
			if r.is_crit:
				result.is_crit = true
		_apply_offense_special(sk, caster, targets, all_enemies)
	# 支援類技能
	else:
		_apply_support(sk, caster, target, all_enemies)

	skill_played.emit(sk.get("name", skill_id), caster.id, result.hit_weakness, result.is_crit)
	EventBus.skill_executed.emit(skill_id, caster.id, [target.id])
	_track_skill_usage(sk)
	return result

func _resolve_targets(sk: Dictionary, target: Combatant, all_enemies: Array) -> Array:
	match sk.get("target", "single"):
		"all", "all_enemies":
			return all_enemies.filter(func(e): return e.is_alive())
		"random":
			var alive: Array = all_enemies.filter(func(e): return e.is_alive())
			var hits: int = sk.get("hits", 1)
			var picked: Array = []
			for i in hits:
				if alive.is_empty():
					break
				picked.append(alive[randi() % alive.size()])
			return picked
		_:
			return [target]

func _deal_damage(sk: Dictionary, caster: Combatant, target: Combatant) -> Dictionary:
	var r: Dictionary = {"hit_weakness": false, "is_crit": false}
	# 閃避 buff（煙霧彈等）
	if target.has_buff("evade") and randf() < target.buff_value("evade"):
		damage_dealt.emit(target.id, 0, "miss")
		return r
	var dtype: String = sk.get("damage_type", "physical")
	var base: float
	if sk.has("power_formula"):
		base = _eval_formula(sk.power_formula, target)
	else:
		base = sk.get("power", 50) * (caster.attack / 100.0)
	var w_mult: float = _weakness_mult(dtype, target)
	var crit: float = 1.5 if randf() < 0.1 else 1.0
	var buff: float = _buff_mult(caster)
	var final_dmg: int = int(base * w_mult * crit * buff)
	if not sk.get("ignore_defense", false):
		final_dmg = maxi(final_dmg - target.defense, 1)
	apply_damage(target, final_dmg, caster, dtype)
	r.hit_weakness = w_mult >= 2.0
	r.is_crit = crit > 1.0
	if r.hit_weakness and not target.is_downed and target.is_alive():
		target.set_down(true)
		var cnt: int = GameManager.get_flag("weakness_hit_count", 0)
		GameManager.set_flag("weakness_hit_count", cnt + 1)
	return r

## 統一傷害入口：處理護盾 / 反彈
func apply_damage(target: Combatant, dmg: int, attacker: Combatant, dtype: String) -> void:
	if target.has_buff("iron_shirt"):
		var reduced: int = int(dmg * 0.2)
		var reflect: int = int(dmg * 0.5)
		target.take_damage(reduced)
		damage_dealt.emit(target.id, reduced, dtype)
		if attacker and attacker.is_alive():
			attacker.take_damage(reflect)
			damage_dealt.emit(attacker.id, reflect, "reflect")
		return
	if target.has_buff("golden_body"):
		var shield: int = int(target.buff_value("golden_body"))
		var absorbed: int = mini(shield, dmg)
		dmg -= absorbed
		target.consume_buff("golden_body")
	target.take_damage(dmg)
	damage_dealt.emit(target.id, dmg, dtype)

func _eval_formula(formula: String, target: Combatant) -> float:
	match formula:
		"enemy_karma * 1.5":
			return target.karma * 1.5
		"player_karma * 1.5":
			return GameManager.player.karma * 1.5
	return 50.0

func _weakness_mult(dtype: String, target: Combatant) -> float:
	if dtype in target.weaknesses:
		return 2.0
	if dtype in target.resistances:
		return 0.5
	return 1.0

func _buff_mult(c: Combatant) -> float:
	var m: float = 1.0
	if c.has_buff("ascetic_temper"):
		m *= 1.0 + c.buff_value("ascetic_temper", 0.6)
	if status.has_status(c, "weaken"):
		m *= 0.5
	if c.is_player:
		if GameManager.get_flag("buff_berserker_days", 0) is int and GameManager.get_flag("buff_berserker_days", 0) > 0:
			m *= 1.5
		# 哀兵必勝被動
		if "underdog" in GameManager.player.skills_unlocked \
				and c.current_hp < c.max_hp * 0.3:
			m *= 1.8
	return m

func _pay_cost(sk: Dictionary, caster: Combatant) -> bool:
	var cost: Dictionary = sk.get("cost", {})
	if not caster.is_player:
		return true
	if cost.get("karma", 0) > GameManager.player.karma:
		return false
	if cost.get("merit", 0) > GameManager.player.merit:
		return false
	if cost.get("gold_required", 0) > GameManager.player.gold:
		return false
	if cost.get("hp", 0) > 0:
		var hp_cost: int = int(caster.max_hp * cost.hp)
		if caster.current_hp <= hp_cost:
			return false
		caster.take_damage(hp_cost)
	if cost.get("karma", 0) > 0:
		GameManager.add_karma(-cost.karma)
	if cost.get("merit", 0) > 0:
		GameManager.add_merit(-cost.merit)
	return true

func _apply_offense_special(sk: Dictionary, caster: Combatant, targets: Array, _all: Array) -> void:
	var special: String = sk.get("special", "")
	match special:
		"steal_gold":
			var amount: int = randi_range(sk.get("steal_min", 50), sk.get("steal_max", 100))
			GameManager.add_gold(amount)
			gold_stolen.emit(amount)
		"mass_steal_gold":
			var total: int = 0
			for t in targets:
				total += int(t.gold_reward * sk.get("steal_ratio", 0.3))
			GameManager.add_gold(total)
			gold_stolen.emit(total)
		"multi_steal":
			var amount: int = sk.get("steal_per_hit", 500) * targets.size()
			GameManager.add_gold(amount)
			gold_stolen.emit(amount)
		"self_weaken":
			status.apply("weaken", caster, sk.get("duration", 1))
		"chaos", "fear", "seal", "burn", "poison", "stun", "slow":
			for t in targets:
				if t.is_alive():
					status.apply(special, t, sk.get("duration", 2))
	# 附帶效果（功德/業障）
	var side: Dictionary = sk.get("side_effect", {})
	if caster.is_player:
		if side.has("merit"):
			GameManager.add_merit(side.merit)
		if side.has("karma"):
			GameManager.add_karma(side.karma)

func _apply_support(sk: Dictionary, caster: Combatant, target: Combatant, all_enemies: Array) -> void:
	var special: String = sk.get("special", "")
	match special:
		"fear", "seal", "chaos", "weaken", "slow":
			var targets: Array = _resolve_targets(sk, target, all_enemies)
			for t in targets:
				if t.is_alive():
					status.apply(special, t, sk.get("duration", 2))
		"self_buff_atk":
			caster.add_buff("ascetic_temper", sk.get("buff_value", 0.6), sk.get("duration", 2))
		"reflect_shield":
			caster.add_buff("iron_shirt", sk.get("shield_value", 0.8), 1)
		"golden_body":
			caster.add_buff("golden_body", sk.get("shield_value", 200), sk.get("duration", 3))
		"heal_and_cleanse":
			caster.heal(sk.get("heal_value", 100))
			status.clear_negative(caster)
		"gain_karma":
			GameManager.add_karma(sk.get("karma_gain", 35))
		"taunt_and_evade":
			caster.add_buff("evade", sk.get("evade_bonus", 0.5), sk.get("duration", 1))
			for e in all_enemies:
				if e.is_alive():
					status.apply("taunt", e, sk.get("duration", 1))
	var side: Dictionary = sk.get("side_effect", {})
	if caster.is_player:
		if side.has("merit"):
			GameManager.add_merit(side.merit)
		if side.has("karma"):
			GameManager.add_karma(side.karma)

func _track_skill_usage(sk: Dictionary) -> void:
	if sk.get("damage_type", "") == "karma" or sk.get("cost", {}).has("karma"):
		var cnt: int = GameManager.get_flag("karma_skill_count", 0)
		GameManager.set_flag("karma_skill_count", cnt + 1)
		SkillUnlockManager.check_unlocks()

# ─── 敵人行動 ───────────────────────────────────────────

func execute_enemy_action(enemy: Combatant, player: Combatant, allies: Array) -> Dictionary:
	var skill_id: String = _pick_enemy_skill(enemy, player, allies)
	var sk: Dictionary = enemy.skill_defs.get(skill_id, {})
	if sk.is_empty():
		return {}
	var result: Dictionary = {"skill_name": sk.get("name", skill_id), "enemy_id": enemy.id}
	var dtype: String = sk.get("damage_type", "physical")
	if dtype != "support":
		var hits: int = sk.get("hits", 1)
		for i in hits:
			var base: float
			if sk.has("power_formula"):
				base = _eval_formula(sk.power_formula, player)
			else:
				base = sk.get("power", 50) * (enemy.attack / 100.0)
			var dmg: int = int(base)
			if not sk.get("ignore_defense", false):
				dmg = maxi(dmg - player.defense, 1)
			apply_damage(player, dmg, enemy, dtype)
		match sk.get("special", ""):
			"steal_gold":
				var stolen: int = mini(sk.get("steal", 100), GameManager.player.gold)
				GameManager.spend_gold(stolen)
				gold_stolen.emit(-stolen)
			"poison", "burn", "fear", "seal", "slow":
				status.apply(sk.special, player, sk.get("duration", 2))
			"stun":
				if randf() < sk.get("stun_chance", 1.0):
					status.apply("stun", player, sk.get("duration", 1))
	else:
		match sk.get("special", ""):
			"taunt_self_def":
				enemy.add_buff("def_up", sk.get("def_bonus", 0.3), sk.get("duration", 1))
			"self_evade":
				enemy.add_buff("evade", sk.get("evade", 0.6), sk.get("duration", 1))
			"self_heal":
				enemy.heal(sk.get("heal", 80))
			"summon":
				result["summon"] = sk.get("summon_id", "")
				enemy.summoned_backup = true
			"fear", "seal", "weaken":
				status.apply(sk.special, player, sk.get("duration", 2))
				var side: Dictionary = sk.get("side_effect", {})
				if side.has("self_atk"):
					enemy.attack += side.self_atk
			"drain_merit":
				GameManager.add_merit(-sk.get("drain", 20))
				enemy.heal(sk.get("heal_self", 30))
	result["name"] = sk.get("name", skill_id)
	skill_played.emit(result.name, enemy.id, false, false)
	return result

func _pick_enemy_skill(e: Combatant, player: Combatant, allies: Array) -> String:
	var usable: Array = e.skills.filter(func(s): return _condition_met(e, player, allies, s))
	if usable.is_empty():
		usable = [e.skills[0]] if not e.skills.is_empty() else []
	if usable.is_empty():
		return ""
	var hp_ratio: float = float(e.current_hp) / float(e.max_hp)
	match e.ai_pattern:
		"aggressive":
			if hp_ratio < 0.3 and usable.size() > 2:
				return usable[2]
			return usable[randi() % mini(2, usable.size())]
		"defensive":
			if hp_ratio > 0.5 and usable.size() > 1:
				return usable[1]
			return usable[0]
		_:
			return usable[randi() % usable.size()]

func _condition_met(e: Combatant, _player: Combatant, allies: Array, skill_id: String) -> bool:
	var sk: Dictionary = e.skill_defs.get(skill_id, {})
	if sk.get("max_once", false) and e.summoned_backup:
		return false
	var hp_ratio: float = float(e.current_hp) / float(e.max_hp)
	match sk.get("condition", ""):
		"hp_below_50": return hp_ratio < 0.5
		"hp_below_40": return hp_ratio < 0.4
		"hp_below_30": return hp_ratio < 0.3
		"partner_alive":
			return allies.any(func(a): return a != e and a.is_alive())
		"ally_hp_lowest":
			return allies.any(func(a): return a != e and a.is_alive() and a.current_hp < e.current_hp)
		"player_karma_above_50":
			return GameManager.player.karma > 50
	return true
