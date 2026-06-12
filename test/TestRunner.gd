extends Node

## 煙霧測試：Step 1（地圖流程）+ Step 3（完整戰鬥）
## 掛在 root 下，場景切換時不會被釋放

func _ready() -> void:
	_run_test()

func _run_test() -> void:
	await get_tree().process_frame
	# ─── Step 1：地圖載入與觸發器 ───
	print("TEST: 切換至 MapScreen")
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		_fail("MapScreen 未載入")
		return
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	print("TEST: 地點觸發器數量 = %d" % triggers.size())
	if triggers.size() < 4:
		_fail("觸發器數量不足")
		return

	# ─── Step 3：完整戰鬥（弱點 → 總攻擊 → 勝利）───
	print("TEST: 進入戰鬥 street_punk（弱點：merit）")
	SceneRouter.go_to_battle("street_punk")
	var battle: Node = await _wait_for_scene("BattleScreen")
	if battle == null:
		_fail("BattleScreen 未載入")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if battle.state != battle.State.PLAYER_TURN:
		_fail("戰鬥未進入玩家回合，state=%d" % battle.state)
		return
	print("TEST: 玩家回合開始，可用技能 = %s" % str(battle.available_skills()))
	GameManager.switch_job("chanter")
	GameManager.add_merit(20)
	var gold_before: int = GameManager.player.gold
	print("TEST: 使用梵音氣功（merit 全體，命中弱點應觸發 Down → 總攻擊）")
	battle.player_use_skill("sound_wave", 0)
	var result: String = await EventBus.battle_ended
	print("TEST: battle_ended = %s" % result)
	if result != "win":
		_fail("戰鬥結果非勝利：%s" % result)
		return
	map = await _wait_for_scene("MapScreen")
	if map == null:
		_fail("勝利後未返回 MapScreen")
		return
	print("TEST: 金幣 %d → %d（含擊殺獎勵）" % [gold_before, GameManager.player.gold])
	print("TEST: kill_count = %s ｜ weakness_hit_count = %s" % [
		str(GameManager.get_flag("kill_count", 0)),
		str(GameManager.get_flag("weakness_hit_count", 0))])
	if GameManager.get_flag("kill_count", 0) < 1:
		_fail("kill_count 未累計")
		return
	print("TEST PASS: Step 1 + Step 3 驗收流程完整通過")
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null

func _fail(msg: String) -> void:
	push_error("TEST FAIL: %s" % msg)
	get_tree().quit(1)
