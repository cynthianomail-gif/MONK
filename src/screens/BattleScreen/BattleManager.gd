extends Control

## 回合制戰鬥主控（GDD 7.1）：P5 風格弱點連擊 + 總攻擊 + Hold-up

enum State { PLAYER_TURN, ENEMY_TURN, SKILL_ANIM, ALL_OUT, HOLD_UP, END }

const ALL_OUT_DMG: int = 9999
const MAX_ENEMIES: int = 4

signal state_changed(s: State)
signal enemy_weakpoint_hit(id: String)
signal battle_log(text: String)

@onready var executor: Node = $SkillExecutor
@onready var status: Node = $SkillExecutor/StatusEffects
@onready var ui: CanvasLayer = $BattleUI

var state: State = State.PLAYER_TURN
var player_combatant: Combatant
var enemy_combatants: Array = []
var _hits: int = 0
var _enemies_data: Dictionary = {}

func _ready() -> void:
	add_to_group("battle_manager")
	AudioManager.switch_bgm("battle_theme")

func setup(enemy_id: String) -> void:
	_enemies_data = JsonLoader.load_json("res://data/enemies.json")
	_enemies_data.merge(JsonLoader.load_json("res://data/boss.json"))
	var data: Dictionary = _enemies_data.get(enemy_id, {})
	if data.is_empty():
		push_error("BattleManager: 找不到敵人 %s" % enemy_id)
		SceneRouter.go_to_map()
		return
	player_combatant = Combatant.from_player()
	enemy_combatants = [Combatant.from_enemy(enemy_id, data)]
	if data.get("spawn_pair", false):
		enemy_combatants.append(Combatant.from_enemy(enemy_id, data, "_2"))
	status.reset()
	ui.build(player_combatant, enemy_combatants)
	battle_log.emit("遭遇 %s！" % data.get("name", enemy_id))
	EventBus.battle_started.emit(data)
	if data.get("is_boss", false):
		AudioManager.switch_bgm("boss_theme")
	_begin_player_turn()

# ─── 玩家回合 ───────────────────────────────────────────

func _begin_player_turn() -> void:
	if state == State.END:
		return
	if not status.process_turn_start(player_combatant):
		battle_log.emit("無戒動彈不得……")
		_enemy_turn()
		return
	_set_state(State.PLAYER_TURN)
	ui.show_skill_menu(available_skills())

func available_skills() -> Array:
	var job: String = GameManager.player.job
	var result: Array = []
	for id in GameManager.player.skills_unlocked:
		var sk: Dictionary = executor.get_skill(id)
		if sk.is_empty():
			continue
		if sk.get("damage_type", "") == "passive":
			continue
		if sk.get("job", "") != job:
			continue
		result.append(id)
	return result

func can_use(skill_id: String) -> bool:
	var sk: Dictionary = executor.get_skill(skill_id)
	var cost: Dictionary = sk.get("cost", {})
	# 封印中只能用無消耗技能
	if status.has_status(player_combatant, "seal") and not cost.is_empty():
		return false
	if cost.get("karma", 0) > GameManager.player.karma:
		return false
	if cost.get("merit", 0) > GameManager.player.merit:
		return false
	if cost.get("gold_required", 0) > GameManager.player.gold:
		return false
	if cost.get("hp", 0) > 0 and player_combatant.current_hp <= int(player_combatant.max_hp * cost.hp):
		return false
	return true

func player_use_skill(skill_id: String, target_idx: int) -> void:
	if state != State.PLAYER_TURN:
		return
	_set_state(State.SKILL_ANIM)
	var target: Combatant = _valid_target(target_idx)
	if target == null:
		_set_state(State.PLAYER_TURN)
		return
	var sk: Dictionary = executor.get_skill(skill_id)
	var result: Dictionary = executor.execute(skill_id, player_combatant, target, enemy_combatants)
	if result.has("error"):
		battle_log.emit("使不出來……（資源不足）")
		_begin_player_turn()
		return
	if sk.get("is_heat_action", false):
		EventBus.heat_action_triggered.emit(GameManager.player.job)
		_track_heat_achievement()
	await ui.play_skill_effect(sk.get("name", skill_id), result.hit_weakness, result.is_crit)
	_process_result(result)

func _valid_target(idx: int) -> Combatant:
	if idx >= 0 and idx < enemy_combatants.size() and enemy_combatants[idx].is_alive():
		return enemy_combatants[idx]
	for e in enemy_combatants:
		if e.is_alive():
			return e
	return null

func _process_result(r: Dictionary) -> void:
	if r.get("hit_weakness", false):
		_hits += 1
		enemy_weakpoint_hit.emit(r.get("target_id", ""))
		EventBus.combo_count_changed.emit(_hits)
		SkillUnlockManager.check_unlocks()
		battle_log.emit("命中弱點！One More！")
		if _all_downed():
			_all_out_attack()
			return
		_check_end()
		if state != State.END:
			_begin_player_turn()
		return
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_enemy_turn()

# ─── 敵人回合 ───────────────────────────────────────────

func _enemy_turn() -> void:
	_set_state(State.ENEMY_TURN)
	for e in enemy_combatants:
		if not e.is_alive():
			continue
		if e.is_downed:
			e.set_down(false)
			battle_log.emit("%s 爬了起來" % e.display_name)
			continue
		if not status.process_turn_start(e):
			battle_log.emit("%s 無法行動" % e.display_name)
			continue
		var act: Dictionary = executor.execute_enemy_action(e, player_combatant, enemy_combatants)
		if not act.is_empty():
			battle_log.emit("%s 使出「%s」" % [e.display_name, act.get("name", "?")])
		if act.has("summon") and enemy_combatants.size() < MAX_ENEMIES:
			_summon(act.summon)
		await get_tree().create_timer(0.5).timeout
		if not player_combatant.is_alive():
			break
	# 回合結束：狀態結算
	status.process_turn_end(player_combatant)
	player_combatant.tick_buffs()
	for e in enemy_combatants:
		status.process_turn_end(e)
		e.tick_buffs()
	_check_end()
	if state != State.END:
		_hits = 0
		EventBus.combo_count_changed.emit(0)
		_begin_player_turn()

func _summon(summon_id: String) -> void:
	var data: Dictionary = _enemies_data.get(summon_id, {})
	if data.is_empty():
		return
	var c := Combatant.from_enemy(summon_id, data, "_b%d" % enemy_combatants.size())
	enemy_combatants.append(c)
	ui.add_enemy_panel(c)
	battle_log.emit("%s 的兄弟加入戰鬥！" % data.get("name", summon_id))

# ─── 總攻擊 / Hold-up ──────────────────────────────────

func _all_out_attack() -> void:
	_set_state(State.ALL_OUT)
	EventBus.all_out_attack_triggered.emit()
	await ui.play_all_out()
	for e in enemy_combatants:
		if e.is_alive():
			e.take_damage(ALL_OUT_DMG)
	await get_tree().create_timer(0.8).timeout
	_hold_up()

func _hold_up() -> void:
	if enemy_combatants.all(func(e): return not e.is_alive()):
		_check_end()
		return
	_set_state(State.HOLD_UP)
	var choice: String = await ui.show_hold_up_menu()
	match choice:
		"gold":
			var amount: int = _enemy_level() * 50
			GameManager.add_gold(amount)
			battle_log.emit("奪得 %d 金幣！" % amount)
		"info":
			GameManager.set_flag("knows_weakness_" + _current_enemy_type(), true)
			battle_log.emit("得知了敵人的弱點情報")
		"item":
			if randf() > 0.5:
				GameManager.add_merit(10)
				battle_log.emit("獲得了供品（功德 +10）")
			else:
				battle_log.emit("什麼都沒搜到……")
	_check_end()
	if state != State.END:
		_begin_player_turn()

func _all_downed() -> bool:
	return enemy_combatants.all(func(e): return e.is_downed or not e.is_alive())

func _enemy_level() -> int:
	var lv: int = 1
	for e in enemy_combatants:
		lv = maxi(lv, e.level)
	return lv

func _current_enemy_type() -> String:
	return enemy_combatants[0].id if not enemy_combatants.is_empty() else ""

# ─── 勝敗 ──────────────────────────────────────────────

func _check_end() -> void:
	if state == State.END:
		return
	if enemy_combatants.all(func(e): return not e.is_alive()):
		_set_state(State.END)
		_victory()
	elif not player_combatant.is_alive():
		_set_state(State.END)
		_defeat()

func _victory() -> void:
	var gold: int = 0
	var kills: int = 0
	for e in enemy_combatants:
		gold += e.gold_reward
		kills += 1
	if GameManager.get_flag("gold_multiplier_active"):
		gold = int(gold * 1.5)
	await ui.play_victory(gold)
	GameManager.add_gold(gold)
	GameManager.add_merit(15)
	GameManager.set_flag("kill_count", GameManager.get_flag("kill_count", 0) + kills)
	GameManager.player.current_hp = player_combatant.current_hp
	SkillUnlockManager.check_unlocks()
	EventBus.battle_ended.emit("win")
	await get_tree().create_timer(1.0).timeout
	SceneRouter.go_to_map()

func _defeat() -> void:
	await ui.play_defeat()
	EventBus.battle_ended.emit("lose")
	# 人中之龍式失敗：金幣減半，回古廟休養（避免死局）
	GameManager.player.gold = int(GameManager.player.gold / 2.0)
	GameManager.player.current_hp = int(GameManager.player.max_hp / 2.0)
	GameManager.player.last_position = {"x": -18.0, "y": 0.0, "z": 4.0}
	await get_tree().create_timer(1.0).timeout
	SceneRouter.go_to_map()

func _track_heat_achievement() -> void:
	GameManager.set_flag("heat_used_" + GameManager.player.job, true)

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

## 測試用：直接擊倒全部敵人
func force_victory() -> void:
	for e in enemy_combatants:
		e.take_damage(ALL_OUT_DMG * 10)
	_check_end()
