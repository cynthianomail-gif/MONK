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
var _boss: Combatant = null      # 有階段的 Boss 參照（無則為 null）
var _boss_phases: Array = []     # boss.json 的 phases 陣列
var _boss_phase_idx: int = -1    # 目前階段索引（-1 = 非階段型 Boss）
var _boss_hp_seen: int = 0        # 上次見到的 Boss HP（判斷掉血→受擊表情）

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
	_init_boss_phases(data)
	status.reset()
	ui.build(player_combatant, enemy_combatants)
	ui.set_battle_bg(BattleArt.resolve_battle_bg(data))
	if _boss != null and not String(_boss.portrait_moods.get("hurt", "")).is_empty():
		_boss_hp_seen = _boss.current_hp
		_boss.hp_changed.connect(_on_boss_hp_changed)
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
		var cut: String = sk.get("cutscene", "")
		if cut != "":
			await SceneRouter.play_battle_cutscene(cut)
	await ui.play_skill_effect(sk.get("name", skill_id), result.hit_weakness, result.is_crit)
	await _maybe_trigger_boss_phase2()
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
			if e == _boss:
				ui.flash_enemy_mood(_boss, _boss_fig(String(_boss.portrait_moods.get("act", ""))), 0.8)
				ui.boss_vfx(_boss, "attack")
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
	_apply_battle_victory_hooks()
	EventBus.battle_ended.emit("win")
	await get_tree().create_timer(1.0).timeout
	_return_from_battle()

func _defeat() -> void:
	await ui.play_defeat()
	EventBus.battle_ended.emit("lose")
	# 人中之龍式失敗：金幣減半，回古廟休養（避免死局）
	GameManager.player.gold = int(GameManager.player.gold / 2.0)
	GameManager.player.current_hp = int(GameManager.player.max_hp / 2.0)
	GameManager.player.last_position = {"x": -18.0, "y": 0.0, "z": 4.0}
	_clear_battle_return_flags()  # 戰敗回古廟而非原場景，清掉暫存避免外洩到下一場
	await get_tree().create_timer(1.0).timeout
	SceneRouter.go_to_map()

# ─── 戰後回場機制（通用：3D 探索場景觸發戰鬥後回原場景）──────────────
# 觸發端在進戰前設旗標（位置由 SceneRouter.go_to_battle() 的 _store_player_position 存好）：
#   battle_return_scene                 = 回去的場景路徑（空＝回城市地圖）
#   battle_clear_flag_on_win            = 打贏要設 true 的清場旗標（空＝無）
#   battle_return_restore_last_position = 回場後是否還原位置（由目標場景自行讀取）

## 勝利時把「打贏要設的清場旗標」設起來，並清掉暫存欄位。
func _apply_battle_victory_hooks() -> void:
	var clear_flag: String = String(GameManager.get_flag("battle_clear_flag_on_win", ""))
	if clear_flag != "":
		GameManager.set_flag(clear_flag, true)
		GameManager.set_flag("battle_clear_flag_on_win", "")

## 戰後通用返回：有指定 battle_return_scene 就回那裡（並清掉暫存），否則回城市地圖。
func _return_from_battle() -> void:
	var return_scene: String = String(GameManager.get_flag("battle_return_scene", ""))
	if return_scene != "" and ResourceLoader.exists(return_scene):
		GameManager.set_flag("battle_return_scene", "")
		SceneRouter.go_to_scene(return_scene)
	else:
		SceneRouter.go_to_map()

## 戰敗時不回原 3D 場景，清掉回場暫存避免外洩到下一場戰鬥。
func _clear_battle_return_flags() -> void:
	GameManager.set_flag("battle_return_scene", "")
	GameManager.set_flag("battle_clear_flag_on_win", "")
	GameManager.set_flag("battle_return_restore_last_position", false)

func _track_heat_achievement() -> void:
	GameManager.set_flag("heat_used_" + GameManager.player.job, true)

# ─── Boss 階段切換 ──────────────────────────────────────

func _init_boss_phases(data: Dictionary) -> void:
	_boss = null
	_boss_phases = []
	_boss_phase_idx = -1
	if not data.get("is_boss", false):
		return
	var phases: Array = data.get("phases", [])
	if phases.is_empty() or enemy_combatants.is_empty():
		return
	_boss = enemy_combatants[0]
	_boss_phases = phases
	_boss_phase_idx = 0
	_apply_boss_phase(0)  # boss.json 的技能定義在各 phase 內，需主動套用

func _apply_boss_phase(i: int) -> void:
	if _boss == null or i < 0 or i >= _boss_phases.size():
		return
	var phase: Dictionary = _boss_phases[i]
	_boss.skills = phase.get("skills", _boss.skills)
	_boss.skill_defs = phase.get("skill_defs", _boss.skill_defs)
	_boss.ai_pattern = phase.get("ai_pattern", _boss.ai_pattern)

## 玩家技能結算後呼叫：Boss 首次掉到下一階段門檻 → 播轉場過場、切換階段技能/AI。
func _maybe_trigger_boss_phase2() -> void:
	if _boss == null or _boss_phase_idx < 0:
		return
	var next_idx: int = _boss_phase_idx + 1
	if next_idx >= _boss_phases.size():
		return
	if not _boss.is_alive():
		return
	var threshold: float = _boss_phases[next_idx].get("hp_threshold", 0.5)
	if float(_boss.current_hp) / float(_boss.max_hp) > threshold:
		return
	_boss_phase_idx = next_idx
	var cut: String = _boss_phases[next_idx].get("transition_cutscene", "")
	if cut != "":
		await SceneRouter.play_battle_cutscene(cut)
	_apply_boss_phase(next_idx)
	ui.set_enemy_base(_boss, _boss_fig(String(_boss.portrait_moods.get("phase2", ""))))
	ui.boss_vfx(_boss, "phase2")
	battle_log.emit("%s 進入第二階段！" % _boss.display_name)

## Boss 掉血 → 暫態受擊表情（pained）。回血/不變不觸發。
func _on_boss_hp_changed(current: int, _mx: int) -> void:
	if _boss != null and current < _boss_hp_seen and current > 0:
		ui.flash_enemy_mood(_boss, _boss_fig(String(_boss.portrait_moods.get("hurt", ""))), 0.6)
	_boss_hp_seen = current

## Boss 表情/階段路徑 → 優先用 boss/cut/ 去背站姿（缺則退回原框圖）。
func _boss_fig(filename_path: String) -> String:
	return BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, filename_path.get_file())

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

# ─── 道具（戰鬥中使用）─────────────────────────────────
## 玩家回合使用消耗道具：自我施放、消耗一回合、不選敵、不觸發 One More。
func player_use_item(item_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	var items: Dictionary = JsonLoader.load_json("res://data/items.json")
	var data: Dictionary = items.get(item_id, {})
	if data.is_empty():
		return
	if not GameManager.consume_item(item_id):
		return
	_apply_item_effect(data.get("effect", {}))
	battle_log.emit("使用「%s」" % data.get("name", item_id))
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_enemy_turn()  # 道具消耗一回合 → 進敵方回合

## 依 effect.kind 套用——複用既有戰鬥效果機制（不經 SkillExecutor）。
func _apply_item_effect(effect: Dictionary) -> void:
	match effect.get("kind", ""):
		"heal":
			player_combatant.heal(int(effect.get("value", 0)))
		"karma":
			GameManager.add_karma(int(effect.get("value", 0)))
		"merit":
			GameManager.add_merit(int(effect.get("value", 0)))
		"shield":
			player_combatant.add_buff("golden_body", float(effect.get("value", 0)), int(effect.get("duration", 3)))
		"cleanse":
			status.clear_negative(player_combatant)

## 測試用：直接擊倒全部敵人
func force_victory() -> void:
	for e in enemy_combatants:
		e.take_damage(ALL_OUT_DMG * 10)
	_check_end()
