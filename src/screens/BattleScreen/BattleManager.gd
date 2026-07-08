extends Control

## 回合制戰鬥主控（GDD 7.1）：P5 風格弱點連擊 + 總攻擊 + Hold-up

enum State { PLAYER_TURN, ENEMY_TURN, SKILL_ANIM, ALL_OUT, HOLD_UP, END }

const ALL_OUT_DMG: int = 9999
const MAX_ENEMIES: int = 4
const GUARD_WINDOW_SECS: float = 0.5   # 完美格擋判定窗（第二期）
const SPEEDUP_SCALE: float = 2.5       # 按住 Shift 加速倍率（QoL：刷道行演出太磨）

# 減傷檔位（第二期第 2 點）：防禦 50%／完美格擋 70%／兩者疊加 90%
const REDUCE_DEFEND: float = 0.5
const REDUCE_PERFECT: float = 0.7
const REDUCE_BOTH: float = 0.9

signal state_changed(s: State)
signal enemy_weakpoint_hit(id: String)
signal battle_log(text: String)

@onready var executor: Node = $SkillExecutor
@onready var status: Node = $SkillExecutor/StatusEffects
@onready var ui: CanvasLayer = $BattleUI
@onready var tutorial: BattleTutorial = $BattleUI/BattleTutorial

var state: State = State.PLAYER_TURN
var player_combatant: Combatant
var enemy_combatants: Array = []
var _hits: int = 0
var _enemies_data: Dictionary = {}

# ─── 行動佇列（第二期第 1 點）───────────────────────────────
## 每回合開始把存活戰鬥者按 speed 降冪排成佇列，依序行動（取代固定我方→敵方）。
var _turn_queue: Array = []     # Array[Combatant]，本回合尚未行動的順序
var _queue_idx: int = 0         # 目前行動者在「本回合完整佇列」的索引（給 TurnOrderBar 高亮）
var _full_queue: Array = []     # 本回合完整佇列快照（渲染用，不隨行動縮短）
var _boss: Combatant = null      # 有階段的 Boss 參照（無則為 null）
var _boss_phases: Array = []     # boss.json 的 phases 陣列
var _boss_phase_idx: int = -1    # 目前階段索引（-1 = 非階段型 Boss）
var _boss_hp_seen: int = 0        # 上次見到的 Boss HP（判斷掉血→受擊表情）
var _boss_data: Dictionary = {}   # 目前 Boss 的 boss.json 原始資料（讀 defeat_cutscene 等欄位用）

# ─── 護法召喚（第四期）───────────────────────────────────
var _summons: Dictionary = {}      # summons.json 內容
var _summons_used: Dictionary = {} # summon_id → true（本場戰鬥已用過，每場每尊限 1 次）

# ─── 按住加速（QoL）────────────────────────────────────
var _speedup_active: bool = false
var _test_speedup_pressed: bool = false   # 測試注入：headless 無鍵盤，模擬按住 Shift

func _ready() -> void:
	add_to_group("battle_manager")
	AudioManager.switch_bgm("battle_theme")

func _process(_delta: float) -> void:
	if state == State.END:
		return
	var pressed: bool = Input.is_key_pressed(KEY_SHIFT) or _test_speedup_pressed
	if pressed != _speedup_active:
		_set_battle_speedup(pressed)

## 測試注入：模擬按住/放開 Shift（headless 無鍵盤）。
func inject_speedup(pressed: bool) -> void:
	_test_speedup_pressed = pressed

func _set_battle_speedup(on: bool) -> void:
	_speedup_active = on
	Engine.time_scale = SPEEDUP_SCALE if on else 1.0
	if ui.has_method("set_speedup_indicator"):
		ui.set_speedup_indicator(on)

func setup(enemy_id: String) -> void:
	_enemies_data = JsonLoader.load_json("res://data/enemies.json")
	_enemies_data.merge(JsonLoader.load_json("res://data/boss.json"))
	_summons = JsonLoader.load_json("res://data/summons.json")
	_summons_used.clear()
	var data: Dictionary = _enemies_data.get(enemy_id, {})
	if data.is_empty():
		push_error("BattleManager: 找不到敵人 %s" % enemy_id)
		SceneRouter.go_to_map()
		return
	player_combatant = Combatant.from_player()
	enemy_combatants = [Combatant.from_enemy(enemy_id, data)]
	if data.get("spawn_pair", false):
		enemy_combatants.append(Combatant.from_enemy(enemy_id, data, "_2"))
	# 異質同場第二敵（ally_id，選用）：與 spawn_pair（同型複製）不同，用於需要「兩隻弱點不同」
	# 的場合（如教學戰：一隻弱物理示範 One More，另一隻中立示範完整敵人回合/格擋，
	# 避免玩家用單一屬性連續打倒全場、跳過敵人出招）。
	var ally_id: String = String(data.get("ally_id", ""))
	if ally_id != "":
		var ally_data: Dictionary = _enemies_data.get(ally_id, {})
		if not ally_data.is_empty():
			enemy_combatants.append(Combatant.from_enemy(ally_id, ally_data))
	_init_boss_phases(data)
	status.reset()
	ui.build(player_combatant, enemy_combatants)
	ui.set_battle_bg(BattleArt.resolve_battle_bg(data))
	if _boss != null and not String(_boss.portrait_moods.get("hurt", "")).is_empty():
		_boss_hp_seen = _boss.current_hp
		_boss.hp_changed.connect(_on_boss_hp_changed)
	battle_log.emit("遭遇　%s" % data.get("name", enemy_id))
	EventBus.battle_started.emit(data)
	if data.get("is_boss", false):
		AudioManager.switch_bgm("boss_theme")
	await tutorial.show_point("intro")
	_start_round()

# ─── 行動佇列（第二期第 1 點）───────────────────────────────

## 回合開始：把所有存活戰鬥者按 speed 降冪排成佇列，依序行動。
func _start_round() -> void:
	if state == State.END:
		return
	_full_queue = _build_turn_queue()
	_turn_queue = _full_queue.duplicate()
	_queue_idx = 0
	_render_turn_order()
	_advance_queue()

## 依 speed 降冪排（同速：玩家優先，其餘依原順序穩定）。
func _build_turn_queue() -> Array:
	var actors: Array = []
	if player_combatant.is_alive():
		actors.append(player_combatant)
	for e in enemy_combatants:
		if e.is_alive():
			actors.append(e)
	actors.sort_custom(func(a, b):
		if a.speed != b.speed:
			return a.speed > b.speed
		# 同速玩家優先
		return a.is_player and not b.is_player)
	return actors

func _render_turn_order() -> void:
	if ui.has_method("render_turn_order"):
		ui.render_turn_order(_full_queue, _queue_idx)

## 取出佇列下一位行動；空了→回合結束結算→下一回合。
func _advance_queue() -> void:
	if state == State.END:
		return
	# 跳過已死者
	while not _turn_queue.is_empty() and not _turn_queue[0].is_alive():
		_turn_queue.pop_front()
		_queue_idx += 1
	if _turn_queue.is_empty():
		_end_round()
		return
	var actor: Combatant = _turn_queue[0]
	_queue_idx = _full_queue.find(actor)
	_render_turn_order()
	if actor.is_player:
		_begin_player_turn()
	else:
		_enemy_single_turn(actor)

## 目前行動者行動完 → 從佇列移除，推進下一位。
func _pop_and_advance() -> void:
	if not _turn_queue.is_empty():
		_turn_queue.pop_front()
	_advance_queue()

## One More：玩家命中弱點 → 在佇列最前插入一次額外玩家行動（不移除當前）。
func _insert_player_extra_action() -> void:
	# 當前玩家 slot 仍在 _turn_queue[0]；不 pop，直接再給一次玩家回合。
	if not _turn_queue.is_empty() and _turn_queue[0].is_player:
		return  # 已在最前，直接重開玩家回合即可
	_turn_queue.push_front(player_combatant)

## 回合結束結算：狀態/buff tick，然後開新回合。
func _end_round() -> void:
	status.process_turn_end(player_combatant)
	player_combatant.tick_buffs()
	player_combatant.is_guarding = false  # 防禦只維持自己那回合
	for e in enemy_combatants:
		status.process_turn_end(e)
		e.tick_buffs()
	_check_end()
	if state != State.END:
		_hits = 0
		EventBus.combo_count_changed.emit(0)
		_start_round()

# ─── 玩家回合 ───────────────────────────────────────────

func _begin_player_turn() -> void:
	if state == State.END:
		return
	if not status.process_turn_start(player_combatant):
		battle_log.emit("動彈不得")
		_pop_and_advance()
		return
	player_combatant.is_guarding = false  # 每次輪到玩家先清，選了防禦才設回
	_set_state(State.PLAYER_TURN)
	await tutorial.show_point("menu")
	if ui.has_method("open_command_menu"):
		ui.open_command_menu(_disabled_commands())
	else:
		ui.show_skill_menu(available_skills())

## 護法指令灰置條件（第四期）：至少 1 尊「未用過且金幣夠」才可選；否則灰置。
## 逃跑指令灰置條件（QoL）：任一敵人 is_boss，或 GameManager flag battle_no_escape 為 true
## （主線/劇情戰由 MainQuestManager 在 go_to_battle 前後設/清）。
func _disabled_commands() -> Array:
	var d: Array = []
	if not _any_summon_available():
		d.append("summon")
	if not _can_flee():
		d.append("flee")
	return d

func _can_flee() -> bool:
	if GameManager.get_flag("battle_no_escape", false):
		return false
	for e in enemy_combatants:
		if e.is_boss:
			return false
	return true

## 是否還有至少一尊護法本場未用過、且金幣足夠請動。
func _any_summon_available() -> bool:
	for sid in _summons.keys():
		if can_summon(sid):
			return true
	return false

## 單尊護法是否可召喚：本場未用過 + 金幣足夠。
func can_summon(summon_id: String) -> bool:
	if _summons_used.get(summon_id, false):
		return false
	var data: Dictionary = _summons.get(summon_id, {})
	if data.is_empty():
		return false
	return GameManager.player.gold >= int(data.get("gold_cost", 0))

## 供 UI 列護法子選單：回傳 summons.json 內容（含已用/金幣不足資訊由 can_summon 判）。
func summon_defs() -> Dictionary:
	return _summons

func summon_used(summon_id: String) -> bool:
	return _summons_used.get(summon_id, false)

## CommandMenu 回傳指令 → 分派。攻擊/技能/道具沿用既有；防禦為新指令。
func on_command(cmd: String) -> void:
	if state != State.PLAYER_TURN:
		return
	match cmd:
		"attack":
			var basic: String = _basic_skill_id()
			if basic != "":
				ui.begin_target_or_use(basic)
		"skill":
			ui.show_skill_menu(available_skills())
		"item":
			ui.show_item_menu()
		"defend":
			player_use_defend()
		"summon":
			ui.show_summon_menu()
		"flee":
			player_use_flee()

## 依職業取 basic 技（攻擊指令＝免費基本攻擊）。
func _basic_skill_id() -> String:
	var job: String = GameManager.player.job
	# basic 技慣例：damage_type 非 passive、無 cost、優先 id 含 basic 或 punch
	for id in GameManager.player.skills_unlocked:
		var sk: Dictionary = executor.get_skill(id)
		if sk.is_empty() or sk.get("job", "") != job:
			continue
		if sk.get("cost", {}).is_empty() and sk.get("damage_type", "") in ["physical", "karma", "merit"]:
			return id
	# fallback：第一個可用技
	var avail: Array = available_skills()
	return avail[0] if not avail.is_empty() else ""

## 防禦指令：本回合減傷 50%（＋完美格擋可疊加至 90%），消耗行動 → 推進佇列。
func player_use_defend() -> void:
	if state != State.PLAYER_TURN:
		return
	player_combatant.is_guarding = true
	battle_log.emit("防禦")
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_pop_and_advance()

## 逃跑指令（QoL）：雜魚戰佛系放生，成功率 100%（灰置條件見 _can_flee）。
## 不算戰鬥結束（不推時段、無獎勵）；漫遊敵抓到的場合要把 roamer_down 補立，
## 否則回街上原地秒被同隻再抓（歷史踩過的坑，同勝利路徑的 _apply_battle_victory_hooks 邏輯）。
func player_use_flee() -> void:
	if state != State.PLAYER_TURN:
		return
	if not _can_flee():
		return
	_set_state(State.END)
	battle_log.emit("三十六計，走為上計")
	await get_tree().create_timer(0.8).timeout
	_apply_battle_victory_hooks()  # 消費 battle_clear_flag_on_win → 立 roamer_down，避免原地被同敵再抓（同勝利路徑）
	EventBus.battle_ended.emit("flee")
	_return_from_battle()  # battle_return_scene 沿用勝利路徑的回場邏輯（同一份旗標）

## 護法召喚（第四期）：花金幣＝香油錢請神，不動業/淨資源。每尊每場限 1 次。
## 消耗一回合 → 佇列下一位（不觸發 One More，同道具指令）。
func player_use_summon(summon_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	if not can_summon(summon_id):
		battle_log.emit("已請過或香油錢不足")
		_begin_player_turn()
		return
	var data: Dictionary = _summons.get(summon_id, {})
	if not GameManager.spend_gold(int(data.get("gold_cost", 0))):
		_begin_player_turn()
		return
	_summons_used[summon_id] = true
	_set_state(State.SKILL_ANIM)
	battle_log.emit("請下　%s" % data.get("name", summon_id))
	await ui.play_summon_effect(summon_id, data)
	_apply_summon_effect(data)
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_pop_and_advance()

## 護法效果結算：damage（單體傷害+擊倒）或 support（全體治療+防禦加持）。
func _apply_summon_effect(data: Dictionary) -> void:
	match String(data.get("effect_kind", "")):
		"damage":
			var target: Combatant = _valid_target(_first_alive_enemy_index())
			if target == null:
				return
			var dtype: String = String(data.get("damage_type", "karma"))
			var base: float = float(data.get("power", 200)) * (player_combatant.attack / 100.0)
			var w_mult: float = 2.0 if dtype in target.weaknesses else (0.5 if dtype in target.resistances else 1.0)
			var dmg: int = maxi(int(base * w_mult) - target.defense, 1)
			executor.apply_damage(target, dmg, player_combatant, dtype)
			if data.get("special", "") == "knockdown" and target.is_alive():
				target.set_down(true)
		"support":
			if data.get("special", "") == "party_heal_and_guard":
				player_combatant.heal(int(data.get("heal_value", 200)))
				player_combatant.add_buff("def_up", float(data.get("def_buff_value", 0.4)), int(data.get("def_buff_duration", 2)))

func _first_alive_enemy_index() -> int:
	for i in enemy_combatants.size():
		if enemy_combatants[i].is_alive():
			return i
	return -1

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
		battle_log.emit("資源不足")
		_begin_player_turn()
		return
	if sk.get("is_heat_action", false):
		EventBus.heat_action_triggered.emit(GameManager.player.job)
		_track_heat_achievement()
		var cut: String = sk.get("cutscene", "")
		if cut != "":
			await SceneRouter.play_battle_cutscene(cut)
	_record_weakness_intel(sk, target)
	await ui.play_skill_effect(sk, result.hit_weakness, result.is_crit, result.get("target_id", ""))
	await _maybe_trigger_boss_phase2()
	await _process_result(result)

## 弱點探知（第一期）：命中屬性 = 敵人弱點 → 記錄並揭曉徽章（跨戰鬥保留、進存檔）。
## 傷害技才探知；命中的目標（單體或全體）逐一比對。
func _record_weakness_intel(sk: Dictionary, primary_target: Combatant) -> void:
	var dtype: String = sk.get("damage_type", "")
	if dtype in ["", "support", "passive"]:
		return
	var targets: Array = []
	if sk.get("target", "single") in ["all", "all_enemies"]:
		targets = enemy_combatants
	else:
		targets = [primary_target]
	for t in targets:
		if t == null:
			continue
		if dtype in t.weaknesses:
			var eid: String = t.base_id if t.base_id != "" else t.id
			if GameManager.record_weakness_intel(eid, dtype):
				battle_log.emit("看破弱點　%s" % t.display_name)
	# 揭曉徽章
	if ui.has_method("refresh_all_weakness_badges"):
		ui.refresh_all_weakness_badges()

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
		battle_log.emit("弱點！One More")
		await tutorial.show_point("weakness")
		if _all_downed():
			_all_out_attack()
			return
		_check_end()
		if state != State.END:
			_insert_player_extra_action()  # One More：插入額外玩家行動
			_begin_player_turn()
		return
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_pop_and_advance()  # 玩家行動完 → 佇列下一位

# ─── 敵人回合 ───────────────────────────────────────────

## 單一敵人行動（佇列驅動）。含完美格擋判定窗（第二期第 2 點）。
func _enemy_single_turn(e: Combatant) -> void:
	_set_state(State.ENEMY_TURN)
	if not e.is_alive():
		_pop_and_advance()
		return
	if e.is_downed:
		e.set_down(false)
		battle_log.emit("%s　起身" % e.display_name)
		_pop_and_advance()
		return
	if not status.process_turn_start(e):
		battle_log.emit("%s　動彈不得" % e.display_name)
		_pop_and_advance()
		return

	# 完美格擋判定窗：出招前先開紅色警示窗，等玩家（或 AI 測試）反應
	await tutorial.show_point("guard")
	await _run_guard_window(e)

	var act: Dictionary = executor.execute_enemy_action(e, player_combatant, enemy_combatants)
	if not act.is_empty():
		ui.enemy_lunge(e)
		battle_log.emit("%s「%s」" % [e.display_name, act.get("name", "?")])
		if ui.has_method("play_enemy_skill_fx"):
			ui.play_enemy_skill_fx(act)
		if e == _boss:
			ui.flash_enemy_mood(_boss, _boss_fig(String(_boss.portrait_moods.get("act", ""))), 0.8)
			ui.boss_vfx(_boss, "attack")
	if act.has("summon") and enemy_combatants.size() < MAX_ENEMIES:
		_summon(act.summon)
	# 敵行動後清掉玩家的完美格擋旗標（只護這一擊）
	player_combatant.perfect_guard_ready = false
	await get_tree().create_timer(0.35).timeout
	_check_end()
	if state != State.END:
		_pop_and_advance()

## 完美格擋判定窗：實機用 UI 的警示光圈＋餵真輸入；headless 用可注入假輸入。
## 命中窗口按 interact(E) → perfect_guard_ready = true（SkillExecutor 讀取套 70%/90% 減傷）。
func _run_guard_window(attacker: Combatant) -> void:
	player_combatant.perfect_guard_ready = false
	var gw := GuardWindow.new(GUARD_WINDOW_SECS)
	gw.open()
	if ui.has_method("show_guard_warning"):
		ui.show_guard_warning(attacker)
	# 逐幀餵真輸入（headless 無鍵盤→自然過期；測試走 inject_guard_input）
	var frames: int = maxi(1, int(GUARD_WINDOW_SECS / 0.05))
	for _i in frames:
		var t := get_tree().create_timer(0.05)
		await t.timeout
		var pressed: bool = Input.is_action_pressed("interact") or _test_guard_pressed
		if gw.tick(0.05, pressed):
			player_combatant.perfect_guard_ready = true
			if ui.has_method("flash_perfect_guard"):
				ui.flash_perfect_guard()
			break
		if not gw.is_open():
			break
	if ui.has_method("hide_guard_warning"):
		ui.hide_guard_warning()

## 測試注入：設 true 模擬玩家在格擋窗按下 interact。
var _test_guard_pressed: bool = false
func inject_guard_input(pressed: bool) -> void:
	_test_guard_pressed = pressed

func _summon(summon_id: String) -> void:
	var data: Dictionary = _enemies_data.get(summon_id, {})
	if data.is_empty():
		return
	var c := Combatant.from_enemy(summon_id, data, "_b%d" % enemy_combatants.size())
	# 防鏈式無限增生根因修正：被召喚出來的援軍直接標記「已召喚過」，牠自己的 call_backup
	# (max_once/summon 類技能)在 _condition_met 會被擋下，不能再召喚下一隻。
	c.summoned_backup = true
	enemy_combatants.append(c)
	ui.add_enemy_panel(c)
	# 援兵加入本回合佇列尾（本回合稍後行動），並更新順序條
	_turn_queue.append(c)
	_full_queue.append(c)
	_render_turn_order()
	battle_log.emit("援軍　%s" % data.get("name", summon_id))

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
			battle_log.emit("金幣 +%d" % amount)
		"info":
			GameManager.set_flag("knows_weakness_" + _current_enemy_type(), true)
			battle_log.emit("弱點情報")
		"item":
			if randf() > 0.5:
				GameManager.add_merit(10)
				battle_log.emit("功德 +10")
			else:
				battle_log.emit("無所獲")
	_check_end()
	if state != State.END:
		_start_round()  # 總攻擊/Hold-up 後重開新回合（重排佇列）

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
	await _maybe_play_defeat_cutscene()
	var gold: int = 0
	var kills: int = 0
	var daoxing: int = 0
	for e in enemy_combatants:
		gold += e.gold_reward
		daoxing += e.level * 15            # 道行基準＝敵 level×15（第二期第 4 點）
		if e.is_boss:
			daoxing += 200                 # Boss 加成
		kills += 1
	if GameManager.get_flag("gold_multiplier_active"):
		gold = int(gold * 1.5)
	await ui.play_victory(gold, 15, daoxing)  # 結算三行：金幣/功德/道行
	GameManager.add_gold(gold)
	GameManager.add_merit(15)
	GameManager.add_daoxing(daoxing)
	GameManager.set_flag("kill_count", GameManager.get_flag("kill_count", 0) + kills)
	GameManager.player.current_hp = player_combatant.current_hp
	SkillUnlockManager.check_unlocks()
	_apply_battle_victory_hooks()
	await tutorial.show_point("victory")
	EventBus.battle_ended.emit("win")
	GameManager.pending_period_advance = true  # 戰鬥結束才推進時段（2026-07-08 拍板）
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
	# 教學戰若中途戰敗：清掉旗標避免殘留影響下一場真實戰鬥（重推本 stage 時對話會重新設回）。
	GameManager.set_flag("tutorial_battle", false)
	GameManager.pending_period_advance = true  # 戰鬥結束（含戰敗）才推進時段（2026-07-08 拍板）
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
	_boss_data = {}
	if not data.get("is_boss", false):
		return
	_boss_data = data
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

## 勝利結算前呼叫：Boss 戰若 boss.json 設有 defeat_cutscene 且素材目錄存在 → 播放戰後過場。
## 素材缺（目錄下沒有 frame_0001.png，例如美術尚未生成）→ 無感跳過，不影響原本勝利流程。
## 缺檔判斷抄自 SceneRouter.play_minigame_cutscene() 的同一模式。
func _maybe_play_defeat_cutscene() -> void:
	var cut: String = String(_boss_data.get("defeat_cutscene", ""))
	if cut == "":
		return
	var dir: String = "res://assets/cutscenes/%s/" % cut
	if not ResourceLoader.exists(dir + "frame_0001.png"):
		return
	await SceneRouter.play_battle_cutscene(cut)

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
	battle_log.emit("%s　第二階段" % _boss.display_name)

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
	if s == State.END:
		_set_battle_speedup(false)  # 戰鬥結束（勝/敗/逃跑）當下立刻還原 time_scale，收尾動畫不受殘留加速影響
	state_changed.emit(s)

## 保險絲：本節點被移出場景樹（換場/queue_free）時，若還在加速中要還原，
## 否則地圖/字卡（用 SceneTreeTimer，受 time_scale 影響）會被殘留加速拖著跑。
func _exit_tree() -> void:
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

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
	battle_log.emit("「%s」" % data.get("name", item_id))
	_hits = 0
	EventBus.combo_count_changed.emit(0)
	_check_end()
	if state != State.END:
		_pop_and_advance()  # 道具消耗一回合 → 佇列下一位

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
