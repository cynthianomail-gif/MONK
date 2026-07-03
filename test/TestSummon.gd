extends Node
## headless 驗證：護法召喚（第四期）。
## 涵蓋：金幣扣款／每場限 1 次／效果結算（傷害+擊倒／治療+防禦buff）／金幣不足擋下／舊存檔相容。
## 跑法：Godot --headless res://test/TestSummon.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_data()
	await _test_gold_deduction_and_effect()
	await _test_once_per_battle()
	await _test_insufficient_gold()
	await _test_command_menu_gating()
	await _test_def_up_interactions()
	_test_old_save_compat()
	print("SUMMON_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _summons() -> Dictionary:
	return JsonLoader.load_json("res://data/summons.json")

func _test_data() -> void:
	var d := _summons()
	_check(d.size() == 2, "summons.json 有 2 尊護法 (got %d)" % d.size())
	_check(d.has("fuhu_luohan"), "有 伏虎羅漢")
	_check(d.has("weituo_tian"), "有 韋馱天")
	_check(int(d.get("fuhu_luohan", {}).get("gold_cost", 0)) == 800, "伏虎羅漢金幣 800")
	_check(int(d.get("weituo_tian", {}).get("gold_cost", 0)) == 600, "韋馱天金幣 600")
	_check(d.get("fuhu_luohan", {}).get("effect_kind", "") == "damage", "伏虎羅漢 damage 型")
	_check(d.get("weituo_tian", {}).get("effect_kind", "") == "support", "韋馱天 support 型")
	for sid in d.keys():
		var portrait: String = String(d[sid].get("portrait", ""))
		_check(portrait != "" and ResourceLoader.exists(portrait), "%s 佔位立繪存在於 %s" % [sid, portrait])

func _make_battle():
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

func _test_gold_deduction_and_effect() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame

	# 伏虎羅漢：扣 800 金幣＋單體傷害＋擊倒（直接呼叫效果結算函式，隔離掉戰鬥回合佇列的
	# 非同步連鎖(敵方站起/回合結算等)，避免與下一段賦值互相踩踏；佇列串接另有 TestBattleFlow 驗）。
	GameManager.player.gold = 1000
	battle._set_state(battle.State.PLAYER_TURN)
	var target = battle.enemy_combatants[0]
	target.max_hp = 5000  # 拉高血量避免一擊必殺，才能單獨驗到「擊倒」而非「陣亡」
	target.current_hp = target.max_hp
	target.set_down(false)
	_check(GameManager.spend_gold(int(battle._summons.fuhu_luohan.gold_cost)), "扣款成功")
	battle._summons_used["fuhu_luohan"] = true
	battle._apply_summon_effect(battle._summons.fuhu_luohan)
	_check(GameManager.player.gold == 200, "召喚伏虎羅漢扣金幣 800 (got %d)" % GameManager.player.gold)
	_check(target.current_hp < target.max_hp, "伏虎羅漢對敵造成傷害 (hp=%d/%d)" % [target.current_hp, target.max_hp])
	_check(target.is_downed, "伏虎羅漢附加擊倒")
	_check(battle.summon_used("fuhu_luohan"), "伏虎羅漢標記為本場已用")

	# 韋馱天：扣 600 金幣＋治療＋防禦 buff（同樣直接呼叫效果結算，隔離佇列連鎖）
	GameManager.player.gold = 1000
	battle.player_combatant.max_hp = 500
	battle.player_combatant.current_hp = 100
	_check(GameManager.spend_gold(int(battle._summons.weituo_tian.gold_cost)), "扣款成功")
	battle._summons_used["weituo_tian"] = true
	battle._apply_summon_effect(battle._summons.weituo_tian)
	_check(GameManager.player.gold == 400, "召喚韋馱天扣金幣 600 (got %d)" % GameManager.player.gold)
	_check(battle.player_combatant.current_hp == 320, "韋馱天治療 +220 (got %d)" % battle.player_combatant.current_hp)
	_check(battle.player_combatant.has_buff("def_up"), "韋馱天附加 def_up 防禦buff")
	_check(battle.summon_used("weituo_tian"), "韋馱天標記為本場已用")

	# def_up buff 實際生效：傷害按比例減免
	var exec: Node = battle.executor
	var p := Combatant.new(); p.is_player = true; p.max_hp = 1000; p.current_hp = 1000
	p.add_buff("def_up", 0.4, 2)
	exec.apply_damage(p, 100, null, "physical")
	_check(1000 - p.current_hp == 60, "def_up 0.4 減傷 40%% (受 60，got %d)" % (1000 - p.current_hp))

	battle.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame

func _test_once_per_battle() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	GameManager.player.gold = 5000
	battle._set_state(battle.State.PLAYER_TURN)
	await battle.player_use_summon("fuhu_luohan")
	var gold_after_first: int = GameManager.player.gold
	_check(not battle.can_summon("fuhu_luohan"), "用過一次後 can_summon 回 false")
	battle._set_state(battle.State.PLAYER_TURN)
	await battle.player_use_summon("fuhu_luohan")  # 第二次應被擋下
	_check(GameManager.player.gold == gold_after_first, "同尊護法第二次召喚不扣款（每場限1次）(got %d, expect %d)" % [GameManager.player.gold, gold_after_first])
	battle.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame

func _test_insufficient_gold() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	GameManager.player.gold = 100  # 不足以請動任何一尊
	_check(not battle.can_summon("fuhu_luohan"), "金幣不足時 can_summon(伏虎羅漢) 回 false")
	_check(not battle.can_summon("weituo_tian"), "金幣不足時 can_summon(韋馱天) 回 false")
	battle._set_state(battle.State.PLAYER_TURN)
	await battle.player_use_summon("fuhu_luohan")
	_check(GameManager.player.gold == 100, "金幣不足時召喚不扣款")
	_check(not battle.summon_used("fuhu_luohan"), "金幣不足時不標記已用")
	battle.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame

func _test_command_menu_gating() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	# 金幣充足、兩尊都沒用過 → 護法指令不灰置
	GameManager.player.gold = 5000
	battle._summons_used.clear()
	_check(battle._disabled_commands().is_empty(), "兩尊皆可用時 summon 指令不灰置")
	# 兩尊都用過 → 灰置
	battle._summons_used = {"fuhu_luohan": true, "weituo_tian": true}
	_check("summon" in battle._disabled_commands(), "兩尊皆用過後 summon 指令灰置")
	# 金幣不足兩尊都請不起 → 灰置
	battle._summons_used.clear()
	GameManager.player.gold = 50
	_check("summon" in battle._disabled_commands(), "金幣不足兩尊皆請不起時 summon 指令灰置")
	battle.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame

## def_up 互動（第四期修復死碼後的行為定錨）：
## (a) 敵方 taunt_self_def 施放 → 帶 def_up buff → 真實減傷生效（原為死碼）。
## (b) 玩家端 防禦50%/完美格擋70%/疊加90% 與 def_up 疊乘，不出 0/負傷害（下限 1）。
func _test_def_up_interactions() -> void:
	var exec: Node = load("res://src/screens/BattleScreen/SkillExecutor.gd").new()
	var status: Node = load("res://src/screens/BattleScreen/StatusEffects.gd").new()
	status.name = "StatusEffects"
	exec.add_child(status)
	add_child(exec)
	await get_tree().process_frame

	# (a) 敵方 taunt_self_def 端到端：施放 → def_up buff → 玩家打過去實際減傷
	var e := Combatant.new()
	e.max_hp = 1000; e.current_hp = 400  # <50% 滿足 provoke 條件
	e.attack = 25
	e.ai_pattern = "aggressive"
	e.skills = ["provoke"]
	e.skill_defs = {"provoke": {"name": "尋釁滋事", "damage_type": "support", "special": "taunt_self_def", "def_bonus": 0.3, "duration": 1, "condition": "hp_below_50"}}
	var pl := Combatant.new(); pl.is_player = true; pl.max_hp = 500; pl.current_hp = 500; pl.defense = 10
	var act: Dictionary = exec.execute_enemy_action(e, pl, [e])
	_check(not act.is_empty(), "敵方 taunt_self_def 行動有執行")
	_check(e.has_buff("def_up"), "施放後敵方帶 def_up buff")
	_check(absf(e.buff_value("def_up") - 0.3) < 0.001, "def_up 值 0.3 (got %.2f)" % e.buff_value("def_up"))
	exec.apply_damage(e, 100, null, "physical")
	_check(400 - e.current_hp == 70, "敵方 def_up 0.3 真實減傷 30%%（受 70，got %d）" % (400 - e.current_hp))

	# (b1) 玩家 防禦50% × def_up 0.4 疊乘：100 → 50 → 30
	var p1 := Combatant.new(); p1.is_player = true; p1.max_hp = 1000; p1.current_hp = 1000
	p1.is_guarding = true
	p1.add_buff("def_up", 0.4, 2)
	exec.apply_damage(p1, 100, null, "physical")
	_check(1000 - p1.current_hp == 30, "防禦50%% × def_up40%% 疊乘受 30 (got %d)" % (1000 - p1.current_hp))

	# (b2) 防禦+完美格擋90% × def_up 0.4：100 → 10 → 5
	# （int 截斷＋IEEE double 的 0.6 略小於精確值 → int(10×(1.0-0.4))=5 而非 6；重點是正值且疊乘正確）
	var p2 := Combatant.new(); p2.is_player = true; p2.max_hp = 1000; p2.current_hp = 1000
	p2.is_guarding = true; p2.perfect_guard_ready = true
	p2.add_buff("def_up", 0.4, 2)
	exec.apply_damage(p2, 100, null, "physical")
	_check(1000 - p2.current_hp == 5, "防禦+完美90%% × def_up40%% 疊乘受 5 (got %d)" % (1000 - p2.current_hp))
	_check(1000 - p2.current_hp >= 1, "疊加後傷害仍為正值（不出 0/負/免傷破表）")

	# (b3) 極端疊加不出 0/負傷害：90% × def_up 0.95 → int(10×0.05)=0 → 下限夾 1
	var p3 := Combatant.new(); p3.is_player = true; p3.max_hp = 1000; p3.current_hp = 1000
	p3.is_guarding = true; p3.perfect_guard_ready = true
	p3.add_buff("def_up", 0.95, 1)
	exec.apply_damage(p3, 100, null, "physical")
	_check(1000 - p3.current_hp == 1, "極端疊加傷害下限 1，不出 0/負傷害 (got %d)" % (1000 - p3.current_hp))

	exec.queue_free()
	await get_tree().process_frame

## 舊存檔相容：護法系統不依賴任何新 player 鍵（純戰鬥內 local state `_summons_used`），
## 缺 daoxing/weakness_intel/board_unlocked 等鍵時 setup()/can_summon() 仍不崩。
func _test_old_save_compat() -> void:
	var saved: Dictionary = GameManager.player.duplicate(true)
	GameManager.player.erase("daoxing")
	GameManager.player.erase("weakness_intel")
	GameManager.player.erase("board_unlocked")
	GameManager.player.gold = 5000
	var battle = _make_battle()
	_check(is_instance_valid(battle), "缺戰鬥新鍵時 BattleScreen 仍可實例化")
	battle.setup("street_punk")
	_check(not battle.enemy_combatants.is_empty(), "缺新鍵時 setup 仍正常執行")
	_check(battle.can_summon("fuhu_luohan"), "缺新鍵時 can_summon 仍正常判斷（不因缺鍵而崩潰）")
	battle.queue_free()
	GameManager.player = saved
