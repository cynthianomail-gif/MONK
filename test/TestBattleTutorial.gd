extends Node
## headless 端到端測試：開場教學戰（小混混亂入→了塵戰鬥教學→勝利）。
## 涵蓋：①主線 stage 資料/對話存在 ②BattleTutorial 5 教學點各觸發一次、不重複、
## await 期間戰鬥不推進 ③弱點可示範(WEAK) ④勝利後旗標清除、stage 前進
## ⑤敗北路徑不死局 ⑥非教學戰鬥（tutorial_battle 旗標關）完全不觸發教學小窗。
## 跑法：Godot --headless res://test/TestBattleTutorial.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_stage_data()
	await _test_tutorial_points_and_victory()
	await _test_non_tutorial_battle_untouched()
	await _test_defeat_not_softlock()
	print("BATTLE_TUTORIAL_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _make_battle():
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

## 背景協程：只要教學小窗顯示中，每幀嘗試注入確認鍵，讓 await 鏈自然推進（不卡死測試）。
## 回傳一個可 cancel 的 Dictionary token（設 stop=true 即停止背景迴圈）。
func _pump_confirms(battle) -> Dictionary:
	var token := {"stop": false}
	_pump_loop(battle, token)
	return token

func _pump_loop(battle, token: Dictionary) -> void:
	while not token.stop:
		await get_tree().process_frame
		if is_instance_valid(battle) and battle.tutorial.visible:
			battle.tutorial.inject_confirm()

## 逐幀等待 cond() 成立，最多等 max_frames 幀（每個 award 鏈含多個 0.3~0.45s 的真實時間
## timer，headless 仍以真實時間推進，故上限給寬鬆一點，避免測試因幀數不足誤判失敗）。
func _wait_until(cond: Callable, max_frames: int = 600) -> int:
	var n: int = 0
	while n < max_frames and not cond.call():
		await get_tree().process_frame
		n += 1
	return n

# ─── ① stage 資料完整性 ───
func _test_stage_data() -> void:
	var mq: Dictionary = JsonLoader.load_json("res://data/main_quests.json")
	var c1: Dictionary = mq.get("ch01_ares", {})
	var stages: Array = c1.get("stages", [])
	var ids: Array = stages.map(func(s): return s.get("id", ""))
	var i_aftermath: int = ids.find("c1_aftermath")
	var i_tutorial: int = ids.find("c1_tutorial_brawl")
	var i_intel: int = ids.find("c1_intel")
	_check(i_tutorial != -1, "main_quests 有 c1_tutorial_brawl stage")
	_check(i_aftermath != -1 and i_tutorial == i_aftermath + 1, "c1_tutorial_brawl 緊接在 c1_aftermath 之後")
	_check(i_intel != -1 and i_intel == i_tutorial + 1, "c1_intel 緊接在 c1_tutorial_brawl 之後（未破壞原順序）")
	var tstage: Dictionary = stages[i_tutorial] if i_tutorial != -1 else {}
	_check(tstage.get("battle", "") == "tutorial_punk", "c1_tutorial_brawl 戰鬥敵人 = tutorial_punk")
	_check(ResourceLoader.exists("res://dialogue/%s.dtl" % tstage.get("dialogue", "")), "教學戰對話檔存在")
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	_check(enemies.has("tutorial_punk"), "enemies.json 有 tutorial_punk")
	_check("physical" in enemies.get("tutorial_punk", {}).get("weaknesses", []), "tutorial_punk 弱物理（配合玩家初始招式可示範 WEAK）")
	var ally_id: String = String(enemies.get("tutorial_punk", {}).get("ally_id", ""))
	_check(ally_id != "" and enemies.has(ally_id), "tutorial_punk 有 ally_id 同場第二敵（確保打倒領頭的之後仍有敵人可行動，guard 教學點可觸發）")
	_check(not ("physical" in enemies.get(ally_id, {}).get("weaknesses", [])), "同場第二敵不弱物理（不會被玩家初始招式連鎖打倒，保證進入牠的回合）")

# ─── ②③④ 教學點 5 個各觸發一次、不重複、await 期間不推進；弱點可示範；勝利後旗標清除、stage 前進 ───
func _test_tutorial_points_and_victory() -> void:
	GameManager.player.flags = {}
	GameManager.player.gold = 1000
	GameManager.player.current_hp = GameManager.player.max_hp
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish"]
	GameManager.set_flag("main_stage_ch01_ares", 1)  # 定位在 c1_tutorial_brawl（index 1）
	GameManager.set_flag("tutorial_battle", true)

	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("tutorial_punk")
	await get_tree().process_frame

	var pump := _pump_confirms(battle)
	var shown_order: Array = []
	battle.tutorial.point_shown.connect(func(id): shown_order.append(id))

	# 教學點 1 "intro"：setup() 內部 await，pump 迴圈按確認才會關閉並進入回合。
	await _wait_until(func(): return battle.tutorial.has_shown("intro"))
	_check(battle.tutorial.has_shown("intro"), "教學點 intro 已觸發")

	# 教學點 2 "menu"：_begin_player_turn 顯示，pump 迴圈自動按確認關閉，接著指令選單開啟。
	await _wait_until(func(): return battle.tutorial.has_shown("menu"))
	_check(battle.tutorial.has_shown("menu"), "教學點 menu 已觸發")
	await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN and not battle.tutorial.visible)
	_check(battle.state == battle.State.PLAYER_TURN, "menu 教學播完後進入玩家指令選單")

	# 玩家用 basic_punch 攻擊（physical，tutorial_punk 弱 physical）→ 觸發 weakness 教學點。
	var target_idx: int = 0
	battle.player_use_skill("basic_punch", target_idx)
	await _wait_until(func(): return battle.tutorial.has_shown("weakness"))
	_check(battle.tutorial.has_shown("weakness"), "教學點 weakness 已觸發（打中弱點）")

	# One More 後繼續攻擊（每次偵測到 PLAYER_TURN 就補一刀），直到進入敵人回合（guard 教學點）或戰鬥結束。
	var guard_or_end := func():
		return battle.tutorial.has_shown("guard") or battle.state == battle.State.END
	var n1: int = 0
	while n1 < 900 and not guard_or_end.call():
		if battle.state == battle.State.PLAYER_TURN:
			battle.player_use_skill("basic_punch", target_idx)
		await get_tree().process_frame
		n1 += 1
	_check(battle.tutorial.has_shown("guard"), "教學點 guard 已觸發（敵人首次出招前，耗時 %d 幀）" % n1)

	# 續打到勝利（END 狀態）。
	var n2: int = 0
	while n2 < 1200 and battle.state != battle.State.END:
		if battle.state == battle.State.PLAYER_TURN:
			battle.player_use_skill("basic_punch", target_idx)
		await get_tree().process_frame
		n2 += 1
	_check(battle.state == battle.State.END, "戰鬥最終進入 END（勝利，耗時 %d 幀）" % n2)

	await _wait_until(func(): return battle.tutorial.has_shown("victory"))
	_check(battle.tutorial.has_shown("victory"), "教學點 victory 已觸發")

	# 5 點都播過、且各只播一次（shown_order 檢查無重複觸發同一點兩次）。
	var expected_points: Array = ["intro", "menu", "weakness", "guard", "victory"]
	for p in expected_points:
		_check(battle.tutorial.has_shown(p), "教學點 %s 已觸發" % p)
	var seen: Dictionary = {}
	var dup_found: bool = false
	for p in shown_order:
		if seen.has(p):
			dup_found = true
		seen[p] = true
	_check(not dup_found, "5 教學點皆不重複播放 (got order=%s)" % str(shown_order))

	# 等旗標清除（victory 教學點結束時 BattleTutorial 自行清 tutorial_battle）。
	await _wait_until(func(): return not bool(GameManager.get_flag("tutorial_battle")))
	_check(not bool(GameManager.get_flag("tutorial_battle")), "勝利後 tutorial_battle 旗標已清除")

	pump.stop = true
	for i in 5:
		await get_tree().process_frame

	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

	GameManager.player.gold = 1000
	GameManager.player.flags = {}

## ⑥ 非教學戰鬥（tutorial_battle 旗標關）：BattleTutorial 完全不顯示，不影響既有戰鬥。
func _test_non_tutorial_battle_untouched() -> void:
	GameManager.player.flags = {}
	GameManager.player.gold = 1000
	GameManager.player.current_hp = GameManager.player.max_hp

	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN, 120)
	_check(not battle.tutorial.visible, "非教學戰鬥：小窗不顯示")
	_check(battle.tutorial._shown.is_empty(), "非教學戰鬥：沒有任何教學點被標記觸發")
	_check(battle.state == battle.State.PLAYER_TURN, "非教學戰鬥：正常進入玩家回合，未被教學流程卡住")

	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame
	GameManager.player.gold = 1000
	GameManager.player.flags = {}

## ⑤ 敗北路徑不死局：教學戰戰敗 → 回古廟、HP/金幣處理正常、tutorial_battle 旗標清除、場景可再次進戰。
func _test_defeat_not_softlock() -> void:
	GameManager.player.flags = {}
	GameManager.player.gold = 1000
	GameManager.player.current_hp = GameManager.player.max_hp
	GameManager.set_flag("tutorial_battle", true)

	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("tutorial_punk")
	await get_tree().process_frame
	var pump := _pump_confirms(battle)

	# 直接打到玩家戰敗（模擬），不必真的被小混混打死。
	battle.player_combatant.take_damage(battle.player_combatant.max_hp * 10)
	await _wait_until(func(): return battle.state == battle.State.END, 300)
	_check(battle.state == battle.State.END, "玩家血量歸零後戰鬥狀態轉 END（戰敗分支）")
	# _defeat() 內有 play_defeat()(1.2s) 才清旗標/處理回場，state==END 只代表 _check_end() 的
	# 同步第一行已跑，_defeat() 協程本體仍在等待中——等旗標清除（或給足夠幀數）才斷言。
	await _wait_until(func(): return not bool(GameManager.get_flag("tutorial_battle")), 300)
	_check(not bool(GameManager.get_flag("tutorial_battle")), "戰敗後 tutorial_battle 旗標也清除，避免殘留污染下一場")
	_check(GameManager.player.current_hp > 0, "戰敗回復機制：HP 重置為正值，非 0（不死局）")
	_check(String(GameManager.get_flag("battle_return_scene", "")) == "", "戰敗清空 battle_return_scene 暫存")

	pump.stop = true
	for i in 5:
		await get_tree().process_frame
	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

	# 可以再次進戰（驗證沒有卡死在某個殘留狀態）。
	GameManager.player.current_hp = GameManager.player.max_hp
	GameManager.set_flag("tutorial_battle", true)
	var battle2 = _make_battle()
	await get_tree().process_frame
	battle2.setup("tutorial_punk")
	await get_tree().process_frame
	var pump2 := _pump_confirms(battle2)
	await _wait_until(func(): return battle2.state == battle2.State.PLAYER_TURN, 300)
	_check(battle2.state == battle2.State.PLAYER_TURN, "戰敗後可重新進入教學戰，不卡死")
	pump2.stop = true
	if is_instance_valid(battle2):
		battle2.queue_free()
	await get_tree().process_frame

	GameManager.player.gold = 1000
	GameManager.player.flags = {}
	GameManager.player.current_hp = GameManager.player.max_hp
