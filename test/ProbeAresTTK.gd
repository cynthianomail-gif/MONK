extends Node
## ares 弱點表填入後的 TTK 三情境驗證（headless）。
## 派工單：D:\monk\_ares_balance_report.md 的驗收依據。
## (a) 開局3招（basic_punch/wooden_fish/arhat_strike）——維持設計壓力，但確認非 0 傷軟死鎖。
## (b) 5招含1招弱點（+broken_bowl_beg[phys,無弱點加成]+sound_wave[merit,命中弱點]）——TTK 應落入合理帶。
## (c) 全解鎖配置（含修行盤三技能＋全部支線技能）——弱點倍率不失控、不秒殺。
## 跑法：Godot --headless --path D:/monk/MONK res://test/ProbeAresTTK.tscn

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	await _scenario_a_opening_3()
	await _scenario_b_5_with_weakness()
	await _scenario_c_full_unlock()
	print("PROBE_ARES_TTK: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _fail(msg: String) -> void:
	ok = false
	print("PROBE FAIL: ", msg)

func _make_battle() -> Node:
	var battle_scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = battle_scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

## 模擬迴圈：輪替 skill_cycle 出招直到 boss 死或 turn_cap 到頂。
## 敵方反擊簡化為固定 war_strike 傷害（同 ProbeSmoke 手法），忽略防禦/道具/護法（純粹量級估計，真實遊玩應更從容）。
## count_player_death：是否讓玩家陣亡中止模擬（情境a要看軟死鎖=需要；情境b/c純測純輸出DPS上限=不中止，
## 玩家陣亡與否另外記錄供參考，理由：情境b/c目的是量測「弱點路線的傷害輸出能力」本身，
## 若用同一個「固定值敵方反擊」模型讓玩家在第8回合必死，會把所有情境的 TTK 都錯誤地封頂在8回合，
## 這是簡化模型的產物而非遊戲真實限制（真實遊玩有防禦/完美格擋/道具/護法可用，如 ProbeSmoke B6 已註記）。
func _simulate(skill_cycle: Array, turn_cap: int, label: String, count_player_death: bool = true) -> Dictionary:
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	GameManager.player.gold = 5000

	var battle := _make_battle()
	await get_tree().process_frame
	battle.setup("ares")
	await get_tree().process_frame

	var boss_data: Dictionary = JsonLoader.load_json("res://data/boss.json").get("ares", {})
	var boss: Combatant = battle.enemy_combatants[0]
	var player: Combatant = battle.player_combatant
	var exec: Node = battle.executor

	var turn: int = 0
	var player_died: bool = false
	var boss_hp_start: int = boss.current_hp
	# skill_cycle[0] 視為「已知弱點招」，玩家找到弱點後理應優先使用（符合遊戲設計鼓勵弱點探知的核心玩法），
	# 資源足夠就用弱點招，不足才輪替其餘技能墊資源——比機械輪替更貼近真實玩家行為。
	var weakness_skill: String = skill_cycle[0]
	var fallback_cycle: Array = skill_cycle.slice(1) if skill_cycle.size() > 1 else skill_cycle
	while boss.is_alive() and turn < turn_cap:
		var skill_id: String = weakness_skill
		var sk: Dictionary = exec.get_skill(skill_id)
		var cost: Dictionary = sk.get("cost", {})
		if cost.get("karma", 0) > GameManager.player.karma or cost.get("merit", 0) > GameManager.player.merit:
			skill_id = fallback_cycle[turn % fallback_cycle.size()]
			sk = exec.get_skill(skill_id)
			cost = sk.get("cost", {})
			if cost.get("karma", 0) > GameManager.player.karma or cost.get("merit", 0) > GameManager.player.merit:
				skill_id = fallback_cycle[0]
				sk = exec.get_skill(skill_id)
		exec.execute(skill_id, player, boss, [boss])
		turn += 1
		GameManager.player.karma = 100
		GameManager.player.merit = 100
		if not boss.is_alive():
			break
		var boss_atk: int = int(boss_data.get("attack", 80))
		var dmg_to_player: int = maxi(boss_atk - player.defense, 1)
		exec.apply_damage(player, dmg_to_player, boss, "physical")
		if not player.is_alive():
			player_died = true
			if count_player_death:
				break
			else:
				player.current_hp = player.max_hp  # 情境b/c目的是量測輸出上限，非死鎖判定；死亡記錄但續打

	var dmg_dealt: int = boss_hp_start - boss.current_hp
	var pct: float = 100.0 * float(dmg_dealt) / float(boss_hp_start) if boss_hp_start > 0 else 0.0
	print("[%s] turns=%d boss_alive=%s boss_hp=%d/%d (%.1f%% dealt) player_hp=%d/%d player_died=%s" % [
		label, turn, boss.is_alive(), boss.current_hp, boss_data.get("max_hp", 0), pct,
		player.current_hp, player.max_hp, player_died
	])

	var result := {
		"turns": turn, "boss_alive": boss.is_alive(), "boss_hp": boss.current_hp,
		"boss_max_hp": int(boss_data.get("max_hp", 0)), "pct_dealt": pct,
		"player_died": player_died, "player_hp": player.current_hp
	}
	battle.queue_free()
	await get_tree().process_frame
	return result

# ─── (a) 開局3招：維持設計壓力，但確認非 0 傷軟死鎖 ───────────────
func _scenario_a_opening_3() -> void:
	print("--- (a) 開局3招 basic_punch/wooden_fish/arhat_strike ---")
	var r: Dictionary = await _simulate(["arhat_strike", "basic_punch", "wooden_fish"], 8, "A_OPENING3")
	if r.pct_dealt <= 0.0:
		_fail("A: 開局3招對 ares 造成 0 傷害，構成軟死鎖")
	else:
		print("A 觀察：8回合造成 %.1f%% 傷害，非0傷（維持設計壓力：三招皆落在抗性內，本就該打不動），玩家死亡=%s" % [r.pct_dealt, r.player_died])
	print("A DONE")

# ─── (b) 5招含1招弱點：TTK 應落入合理帶 ───────────────
func _scenario_b_5_with_weakness() -> void:
	print("--- (b) 5招(含1招merit弱點 sound_wave) ---")
	# 5 招配置：basic_punch/wooden_fish(initial) + arhat_strike(story) + broken_bowl_beg(behavior,易達)
	#          + sound_wave(quest ah_zhong，merit，命中 ares 弱點)
	var r: Dictionary = await _simulate(["sound_wave", "arhat_strike", "broken_bowl_beg", "basic_punch", "wooden_fish"], 40, "B_5SKILL_WEAKNESS", false)
	if not r.boss_alive:
		print("B 觀察：%d 回合擊敗 ares，TTK=%d" % [r.turns, r.turns])
	else:
		print("B 觀察：%d 回合內僅造成 %.1f%%，未擊敗（若上限內未擊敗需檢視弱點倍率是否足夠）" % [r.turns, r.pct_dealt])
	# 目標帶：對照 phase4 報告的中低配裝 TTK 量級（同期敵人 elite temple_ghost 弱點路線 TTK 落在個位數~十餘擊），
	# boss 血量遠高於雜兵(2000 vs 350)，允許帶更寬：合理帶設 8~30 回合（太短=弱點倍率過爆、太長=形同軟死鎖）。
	if r.boss_alive:
		_fail("B: 40 回合內未擊敗 ares，TTK 過長，弱點路線未達合理帶")
	elif r.turns < 8:
		_fail("B: TTK=%d 過短（<8），弱點倍率可能失控/秒殺" % r.turns)
	elif r.turns > 30:
		_fail("B: TTK=%d 過長（>30），弱點路線仍偏軟死鎖" % r.turns)
	else:
		print("B 結論：TTK=%d 回合，落在合理帶 [8,30] 內" % r.turns)
	print("B DONE")

# ─── (c) 全解鎖配置：弱點倍率不失控、不秒殺 ───────────────
func _scenario_c_full_unlock() -> void:
	print("--- (c) 全解鎖配置（含修行盤三技能＋全部支線技能） ---")
	# 全部非 heat 技能循環使用（heat 技能屬處決技，不列入常態 DPS 循環，另計）
	var full_cycle: Array = [
		"sound_wave", "arhat_strike", "lions_roar", "beggars_stride", "alms_wave",
		"vajra_fist_seal", "broken_bowl_beg", "basic_punch", "wooden_fish"
	]
	var r: Dictionary = await _simulate(full_cycle, 40, "C_FULL_UNLOCK", false)
	if not r.boss_alive:
		print("C 觀察：%d 回合擊敗 ares" % r.turns)
		if r.turns <= 3:
			_fail("C: 全解鎖配置 %d 回合內秒殺 ares，弱點/技能強度組合失控" % r.turns)
		else:
			print("C 結論：TTK=%d，非秒殺（>3 回合），弱點倍率在全配裝下未失控" % r.turns)
	else:
		print("C 觀察：40 回合內僅 %.1f%%，全解鎖配裝理應遠快於此，需檢視" % r.pct_dealt)
		_fail("C: 全解鎖配置仍未能在 40 回合內擊敗 ares")
	print("C DONE")
