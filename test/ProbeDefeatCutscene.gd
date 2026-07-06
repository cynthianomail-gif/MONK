extends Node
## headless 驗證：boss defeat_cutscene 接線（BattleManager._maybe_play_defeat_cutscene）。
## 派工來源：阿瑞斯戰後過場接線任務。驗兩條路徑：
## (a) 素材存在（真實 ares/defeat_cutscene="ares_defeated"，61 幀已落地）→ 勝利流程真的 await
##     播放過場，headless 下能跑完不卡死、不噴 SCRIPT ERROR（畫面對錯不管，那是 GPU 實機的事）。
## (b) 素材缺（假 id "zz_no_such_cutscene"，保證不存在）→ 無感跳過，勝利流程正常跑完。
## 跑法：Godot --headless --path D:/monk/MONK res://test/ProbeDefeatCutscene.tscn

var ok: bool = true

func _fail(msg: String) -> void:
	ok = false
	print("PROBE FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	await _case_a_asset_exists()
	await _case_b_asset_missing()
	print("PROBE_DEFEAT_CUTSCENE: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _make_battle() -> Node:
	var battle_scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = battle_scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

## (a) 真實 ares boss，defeat_cutscene="ares_defeated"，素材已存在（61 幀+audio.ogg）。
## 強制擊倒後 await battle._victory() 應該完整跑完（含 await _maybe_play_defeat_cutscene()
## → SceneRouter.play_battle_cutscene("ares_defeated") → CutsceneScreen.play() 播完 61 幀）。
func _case_a_asset_exists() -> void:
	print("--- (a) ares 勝利，defeat_cutscene 素材存在 ---")
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	GameManager.player.gold = 5000

	var battle := _make_battle()
	await get_tree().process_frame
	battle.setup("ares")
	await get_tree().process_frame

	_check_true(battle._boss_data.get("defeat_cutscene", "") == "ares_defeated",
		"battle._boss_data.defeat_cutscene 應為 ares_defeated")

	for e in battle.enemy_combatants:
		e.take_damage(99999)
	battle._check_end()

	# 61 幀 @ 12fps ≈ 5.1 秒播放時間；加上淡入淡出與換場緩衝，給足 12 秒逾時保護，
	# 避免真的卡死時測試無限等待（headless 沒有人工跳過機制）。
	var elapsed: float = 0.0
	var timeout: float = 12.0
	while battle.state != battle.State.END or not GameManager.get_flag("kill_count", 0) and false:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > timeout:
			break

	# 用「等到 _return_from_battle 觸發換場」當完成訊號更可靠：直接輪詢固定幀數，
	# 累積夠長時間讓 61 幀過場（headless 下 CutsceneScreen 仍照 _process(delta) 走完整個 _frames）。
	var frames: int = 0
	while frames < 600:  # 600 幀，遠超過 61 幀@12fps 所需，確保過場播完+淡出+返回結算跑完
		await get_tree().process_frame
		frames += 1
		if not is_instance_valid(battle):
			break

	_check_true(is_instance_valid(battle) and battle.state == battle.State.END,
		"(a) 過場播完後 state 應轉 END（%d 幀內），證明勝利結算真的走完" % frames)
	print("(a) DONE：battle 仍有效=%s state=%s" % [is_instance_valid(battle), battle.state if is_instance_valid(battle) else "N/A"])
	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

## (b) 假 id：defeat_cutscene 缺檔 → _maybe_play_defeat_cutscene 應直接 return，不呼叫
## SceneRouter.play_battle_cutscene，勝利流程照常跑完（不卡死、不報錯）。
func _case_b_asset_missing() -> void:
	print("--- (b) 假 cutscene id，素材不存在，應無感跳過 ---")
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	GameManager.player.gold = 5000

	var battle := _make_battle()
	await get_tree().process_frame
	battle.setup("ares")
	await get_tree().process_frame
	# 直接竄改 _boss_data 的 defeat_cutscene 成保證不存在的假 id，驗證缺檔跳過路徑，
	# 不依賴 ares_defeated 資產「現在還不在」這個已經不成立的前提。
	battle._boss_data["defeat_cutscene"] = "zz_no_such_cutscene"

	var start_ticks: int = Time.get_ticks_msec()
	for e in battle.enemy_combatants:
		e.take_damage(99999)
	battle._check_end()

	var frames: int = 0
	while battle.state != battle.State.END and frames < 120:
		await get_tree().process_frame
		frames += 1
	_check_true(battle.state == battle.State.END, "(b) 假 id 不應卡住勝利流程，state 應轉 END")

	# 缺檔跳過應該幾乎瞬間完成（無 12 秒過場等待），用時間上限佐證沒有誤觸發播放。
	var elapsed_ms: int = Time.get_ticks_msec() - start_ticks
	_check_true(elapsed_ms < 5000, "(b) 缺檔跳過耗時應遠短於真過場播放（實際 %d ms）" % elapsed_ms)
	print("(b) DONE：耗時 %d ms（應遠小於 5000ms，證明沒誤播放過場）" % elapsed_ms)

	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

func _check_true(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)
	else:
		print("  [PASS] ", msg)
