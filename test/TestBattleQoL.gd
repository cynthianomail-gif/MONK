extends Node
## headless 驗證：戰鬥 QoL 兩項——①逃跑指令 ②按住加速。
## 涵蓋：雜魚戰可逃(結束/零獎勵/不推時段/roamer_down 補立)、Boss 灰置逃跑、
## battle_no_escape 旗標灰置逃跑、time_scale 按住變 2.5/戰鬥結束還原。
##
## 重要：逃跑/勝利收尾會真的觸發 SceneRouter.go_to_map()（change_scene_to_file），
## 這會把「當前 current_scene」整個 queue_free（同 TestBattleEntry.gd 的踩過的坑：
## 測試場景自己就是 current_scene，換場時會被釋放，之後 get_tree() 全部變 null）。
## 故測試邏輯掛在 get_tree().root 下的獨立 Runner 節點，不掛在本場景根節點。
## 跑法：Godot --headless res://test/TestBattleQoL.tscn

class Runner extends Node:
	var ok: bool = true

	func _check(cond: bool, msg: String) -> void:
		if not cond:
			ok = false
			print("FAIL: ", msg)

	func _run() -> void:
		await get_tree().process_frame
		await _test_flee_flow_zero_reward()
		await _test_flee_disabled_for_boss()
		await _test_flee_disabled_for_no_escape_flag()
		await _test_speedup_time_scale()
		print("BATTLE_QOL_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
		get_tree().quit(0 if ok else 1)

	func _make_battle():
		var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
		var battle = scene.instantiate()
		get_tree().root.add_child(battle)
		return battle

	func _wait_until(cond: Callable, max_frames: int = 600) -> int:
		var n: int = 0
		while n < max_frames and not cond.call():
			await get_tree().process_frame
			n += 1
		return n

	## a) 雜魚戰逃跑：指令可用→執行後戰鬥結束、零獎勵(gold/merit 不變)、pending_period_advance
	##    仍 false、battle_clear_flag_on_win 有設時 roamer_down 有立。
	func _test_flee_flow_zero_reward() -> void:
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.player.merit = 0
		GameManager.player.current_hp = GameManager.player.max_hp
		GameManager.pending_period_advance = false
		GameManager.set_flag("battle_clear_flag_on_win", "roamer_down_test_e1")

		var battle = _make_battle()
		await get_tree().process_frame
		battle.setup("street_punk")
		await get_tree().process_frame
		await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN, 120)

		var disabled: Array = battle._disabled_commands()
		_check(not ("flee" in disabled), "雜魚戰(street_punk)逃跑指令未被灰置 (disabled=%s)" % str(disabled))

		var gold_before: int = GameManager.player.gold
		var merit_before: int = int(GameManager.player.merit)

		battle.player_use_flee()
		await _wait_until(func(): return battle.state == battle.State.END, 120)
		_check(battle.state == battle.State.END, "逃跑後戰鬥狀態轉為 END")

		# 逃跑收尾協程仍在等待 0.8s timer，接著 _apply_battle_victory_hooks（同步立旗標）
		# → EventBus.emit → _return_from_battle（會真的觸發 change_scene_to_file 換回地圖）。
		# 只等旗標立起就收工斷言，不要等到換場完成才斷言（換場後 battle 節點與本場景都可能
		# 被釋放，多等徒增風險且沒有额外驗證價值）。
		await _wait_until(func(): return bool(GameManager.get_flag("roamer_down_test_e1", false)), 200)
		_check(GameManager.player.gold == gold_before, "逃跑零獎勵：金幣不變 (before=%d, after=%d)" % [gold_before, GameManager.player.gold])
		_check(int(GameManager.player.merit) == merit_before, "逃跑零獎勵：功德不變 (before=%d, after=%d)" % [merit_before, int(GameManager.player.merit)])
		_check(not GameManager.pending_period_advance, "逃跑不推時段：pending_period_advance 仍 false")
		_check(bool(GameManager.get_flag("roamer_down_test_e1", false)), "逃跑時 battle_clear_flag_on_win 指向的 roamer_down 旗標有立")
		_check(String(GameManager.get_flag("battle_clear_flag_on_win", "")) == "", "battle_clear_flag_on_win 暫存已被消費清空")
		_check(Engine.time_scale == 1.0, "逃跑收尾後 time_scale 已還原為 1.0")

		# 給換場鏈（_show_loading/_play_transition/change_scene_to_file）足夠幀數跑完，
		# 讓 current_scene 換回 MapScreen 穩定下來，避免與下一個子測試的 _make_battle 並發。
		for i in 30:
			await get_tree().process_frame

		if is_instance_valid(battle):
			battle.queue_free()
		await get_tree().process_frame
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.pending_period_advance = false

	## b) is_boss 敵人時「逃跑」在 disabled 清單。
	func _test_flee_disabled_for_boss() -> void:
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.player.current_hp = GameManager.player.max_hp

		var battle = _make_battle()
		await get_tree().process_frame
		battle.setup("ares")
		await get_tree().process_frame
		await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN, 120)

		var disabled: Array = battle._disabled_commands()
		_check("flee" in disabled, "Boss(ares) 戰鬥中逃跑指令被灰置 (disabled=%s)" % str(disabled))

		if is_instance_valid(battle):
			battle.queue_free()
		await get_tree().process_frame
		GameManager.player.flags = {}
		GameManager.player.gold = 1000

	## c) battle_no_escape flag 時同灰置（模擬 MainQuestManager 主線戰）。
	func _test_flee_disabled_for_no_escape_flag() -> void:
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.player.current_hp = GameManager.player.max_hp
		GameManager.set_flag("battle_no_escape", true)

		var battle = _make_battle()
		await get_tree().process_frame
		battle.setup("street_punk")
		await get_tree().process_frame
		await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN, 120)

		var disabled: Array = battle._disabled_commands()
		_check("flee" in disabled, "battle_no_escape=true 時逃跑指令被灰置 (disabled=%s)" % str(disabled))

		# 執行也要被擋（防呆：即使 UI 灰置被繞過，玩家回合狀態也不該真的逃跑成功）。
		battle.player_use_flee()
		await get_tree().process_frame
		_check(battle.state == battle.State.PLAYER_TURN, "battle_no_escape=true 時 player_use_flee() 呼叫無效，仍在玩家回合")

		if is_instance_valid(battle):
			battle.queue_free()
		await get_tree().process_frame
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.set_flag("battle_no_escape", false)

	## d) time_scale：模擬按住→2.5、戰鬥結束→1.0。
	func _test_speedup_time_scale() -> void:
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.player.current_hp = GameManager.player.max_hp
		GameManager.pending_period_advance = false

		var battle = _make_battle()
		await get_tree().process_frame
		battle.setup("street_punk")
		await get_tree().process_frame
		await _wait_until(func(): return battle.state == battle.State.PLAYER_TURN, 120)

		_check(Engine.time_scale == 1.0, "戰鬥開場 time_scale 為 1.0（未按住）")
		battle.inject_speedup(true)
		await get_tree().process_frame
		_check(Engine.time_scale == battle.SPEEDUP_SCALE, "按住模擬鍵後 time_scale 變 %s (got %s)" % [battle.SPEEDUP_SCALE, Engine.time_scale])

		# 戰鬥結束（用 force_victory 直接擊倒全部敵人）→ time_scale 應立刻還原，不受殘留加速影響。
		battle.force_victory()
		await get_tree().process_frame
		_check(Engine.time_scale == 1.0, "戰鬥進入 END 狀態後 time_scale 立刻還原為 1.0 (got %s)" % Engine.time_scale)

		battle.inject_speedup(false)
		# 勝利收尾協程會跑完並真的換場回地圖（同逃跑測試的風險），多等幾幀讓它穩定，
		# 但不需要等到換場 100% 結束才斷言——time_scale 的斷言在換場前就已成立。
		for i in 10:
			await get_tree().process_frame
		_check(Engine.time_scale == 1.0, "勝利收尾流程跑完後 time_scale 仍為 1.0")

		if is_instance_valid(battle):
			battle.queue_free()
		await get_tree().process_frame
		Engine.time_scale = 1.0
		GameManager.player.flags = {}
		GameManager.player.gold = 1000
		GameManager.pending_period_advance = false

func _ready() -> void:
	# 測試場景自己會被 change_scene_to_file 釋放（逃跑/勝利收尾都會真的換場回地圖），
	# 邏輯要掛在 root 下的獨立節點才能活過換場（同 TestBattleEntry.gd 的既有做法）。
	var r := Runner.new()
	get_tree().root.add_child.call_deferred(r)
	r.call_deferred("_run")
