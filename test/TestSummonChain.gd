extends Node
## headless 驗證：小混混「叫兄弟來」(call_backup) 不再無限鏈式增生（2026-07-06 修根因）。
## 根因回顧：_summon() 用 Combatant.from_enemy() 造出的新單位 summoned_backup 預設 false，
## 牠自己也帶 call_backup(max_once) → 又能再召喚 → 鏈式增生到 MAX_ENEMIES。
## 修法：①enemies.json call_backup 加 chance:0.2（_condition_met 擲機率，未中不列入可用技能）；
## ②BattleManager._summon() 造出援軍時直接標記 summoned_backup=true，其 call_backup 被
## _condition_met 的 "special==summon and summoned_backup" 擋下，不能再召喚下一隻。
## 跑法：Godot --headless res://test/TestSummonChain.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_chance_field_present()
	_test_summoned_unit_cannot_resummon()
	await _test_no_infinite_chain_in_battle()
	print("SUMMON_CHAIN_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _enemies() -> Dictionary:
	return JsonLoader.load_json("res://data/enemies.json")

func _test_chance_field_present() -> void:
	var d := _enemies()
	var cb: Dictionary = d.get("street_punk", {}).get("skill_defs", {}).get("call_backup", {})
	_check(cb.get("max_once", false), "call_backup 仍是 max_once")
	_check(absf(float(cb.get("chance", 0.0)) - 0.2) < 0.001, "call_backup chance=0.2 (got %s)" % str(cb.get("chance")))

## 直接驗證 _condition_met 的邏輯（不靠隨機性）：summoned_backup=true 的單位，
## call_backup 一律不在可用清單（不論機率、不論血量），杜絕鏈式增生根因。
func _test_summoned_unit_cannot_resummon() -> void:
	var exec: Node = load("res://src/screens/BattleScreen/SkillExecutor.gd").new()
	var status: Node = load("res://src/screens/BattleScreen/StatusEffects.gd").new()
	status.name = "StatusEffects"
	exec.add_child(status)
	add_child(exec)
	await get_tree().process_frame

	var d := _enemies()
	var backup := Combatant.from_enemy("street_punk", d["street_punk"], "_backup")
	backup.summoned_backup = true   # 模擬「這是被召喚出來的援軍」
	backup.current_hp = int(backup.max_hp * 0.1)  # hp_below_30 條件成立
	_check(not exec._condition_met(backup, null, [backup], "call_backup"), \
		"summoned_backup=true 的援軍，call_backup 條件不成立（禁止再召喚）")

	# 對照組：原始(非援軍)小混混，summoned_backup=false，hp<30% → 條件應可能成立（機率控制觸發與否，
	# 但條件本身不該被 summoned_backup 擋下）。多擲幾次，只要曾經 true 就代表條件邏輯正確。
	var original := Combatant.from_enemy("street_punk", d["street_punk"], "_orig")
	original.current_hp = int(original.max_hp * 0.1)
	var ever_true := false
	for i in range(200):
		if exec._condition_met(original, null, [original], "call_backup"):
			ever_true = true
			break
	_check(ever_true, "非援軍小混混 hp<30%% 時，call_backup 在多次擲骰中至少觸發一次（機率未被誤擋）")

	exec.queue_free()
	await get_tree().process_frame

## 端到端：真的在 BattleScreen 內連續呼叫 _summon()（模擬「原始小混混」反覆觸發援軍），
## 驗證：①MAX_ENEMIES 上限本就由呼叫端(_enemy_single_turn)把關，_summon() 本身不重複造超量；
## ②重點＝每隻被 _summon() 造出來的援軍都標記 summoned_backup=true，
##   牠自己的 call_backup 在 _condition_met 會被擋下 → 不會再遞迴召喚，鏈式增生的根因已斷。
func _test_no_infinite_chain_in_battle() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame

	var initial_count: int = battle.enemy_combatants.size()
	# 比照真實呼叫端的把關條件（enemy_combatants.size() < MAX_ENEMIES）反覆嘗試召喚，
	# 驗證上限确实生效（這段把關本來就存在於 _enemy_single_turn，這裡對照驗證沒被動過）。
	for i in range(10):
		if battle.enemy_combatants.size() < battle.MAX_ENEMIES:
			battle._summon("street_punk")
	_check(battle.enemy_combatants.size() == battle.MAX_ENEMIES, \
		"呼叫端把關下，enemy_combatants 精準停在 MAX_ENEMIES=%d (got %d)" \
		% [battle.MAX_ENEMIES, battle.enemy_combatants.size()])

	# 核心驗證：所有被 _summon() 造出的援軍(index>=initial_count)都標記 summoned_backup=true，
	# 意味著牠們的 call_backup 技能會被 _condition_met 擋下，不能再召喚下一隻（鏈式增生根因已斷）。
	var all_marked := true
	for i in range(battle.enemy_combatants.size()):
		if i >= initial_count and not battle.enemy_combatants[i].summoned_backup:
			all_marked = false
	_check(all_marked, "所有被 _summon() 造出的援軍都標記 summoned_backup=true（自己不能再召喚）")

	battle.queue_free()
	await get_tree().process_frame
