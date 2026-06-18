extends Node
## headless 測試：三個小遊戲的計分/判定純邏輯 + 場景煙霧測試。
## 跑法：Godot --headless res://test/TestMinigames.tscn
## 驗證：邏輯正確、三場景能 instantiate 跑數幀不崩。

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_beggar()
	_test_soup()
	_test_wooden_fish()
	await _smoke_scenes()
	print("MINIGAME_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

# --- 化緣 ---
func _test_beggar() -> void:
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	if gs == null:
		_check(false, "beggar script failed to load"); return
	var g = gs.new()
	_check(g.donate_reward("office_worker") == 50, "beggar office_worker=50")
	_check(g.donate_reward("tourist") == 100, "beggar tourist=100")
	_check(g.donate_reward("rich_lady") == 500, "beggar rich_lady=500")
	_check(g.donate_reward("drunk_man") == 10, "beggar drunk_man=10")
	_check(g.donate_reward("rich_lady", true) == 1500, "beggar QR x3 = 1500")
	_check(g.donate_reward("nobody") == 0, "beggar unknown=0")
	g.score = 1000
	g.greed_swings = 10
	var r: Dictionary = g.build_result()
	_check(r.gold == 1000, "beggar result gold=score")
	_check(r.karma == 2, "beggar greed 10/5 -> karma 2 (got %d)" % r.karma)
	g.free()

# --- 端湯 ---
func _test_soup() -> void:
	var gs = load("res://src/screens/Minigames/SoupCarry.gd")
	if gs == null:
		_check(false, "soup script failed to load"); return
	var g = gs.new()
	_check(g.floor_wind_amplitude(3) == 3.0, "soup wind floor3=3")
	_check(g.floor_wind_amplitude(7) == 12.0, "soup wind floor7=12")
	# 穩定握持：不傾斜不溢出、不失敗
	var dead_stable := false
	for i in 30:
		dead_stable = g.step_physics(0.1, 0.0) or dead_stable
	_check(not dead_stable and g.spillage == 0.0, "soup stable -> no spill")
	# 猛烈傾斜：應在合理幀數內溢滿失敗
	var g2 = load("res://src/screens/Minigames/SoupCarry.gd").new()
	var dead := false
	var iters := 0
	while not dead and iters < 300:
		dead = g2.step_physics(0.1, 100.0)
		iters += 1
	_check(dead and g2.spillage >= 100.0, "soup hard tilt -> overflow death (iters=%d)" % iters)
	var won_res: Dictionary = g2.build_result(true)
	_check(won_res.win == true, "soup result win flag")
	g.free()
	g2.free()

# --- 木魚 ---
func _test_wooden_fish() -> void:
	var gs = load("res://src/screens/Minigames/WoodenFishRhythm.gd")
	if gs == null:
		_check(false, "wooden fish script failed to load"); return
	var g = gs.new()
	_check(g.judge_offset(0.0) == "perfect", "fish offset0=perfect")
	_check(g.judge_offset(-55.0) == "perfect", "fish -55=perfect")
	_check(g.judge_offset(100.0) == "good", "fish 100=good")
	_check(g.judge_offset(200.0) == "miss", "fish 200=miss")
	_check(g.score_for("perfect") == 100, "fish perfect=100")
	_check(g.score_for("good") == 50, "fish good=50")
	_check(g.score_for("miss") == 0, "fish miss=0")
	_check(g.decide_win(0.9, 0.82) == true, "fish win when acc>=opp")
	_check(g.decide_win(0.5, 0.82) == false, "fish lose when acc<opp")
	# build_result：32 音符、命中 30 → acc 0.9375 >= 0.82 → win
	g.note_count = 32
	g.opponent_accuracy = 0.82
	g.hits = 30
	g.score = 3000
	var r: Dictionary = g.build_result()
	_check(r.win == true, "fish 30/32 hits -> win")
	g.hits = 10
	var r2: Dictionary = g.build_result()
	_check(r2.win == false, "fish 10/32 hits -> lose")
	g.free()

# --- 場景煙霧測試 ---
func _smoke_scenes() -> void:
	for path in [
		"res://src/screens/Minigames/BeggarChallenge.tscn",
		"res://src/screens/Minigames/SoupCarry.tscn",
		"res://src/screens/Minigames/WoodenFishRhythm.tscn",
	]:
		var ps: PackedScene = load(path)
		if ps == null:
			_check(false, "load scene %s" % path)
			continue
		var inst = ps.instantiate()
		inst.set("auto_start", false)   # 不自動開跑/結束
		get_tree().root.add_child(inst)
		for i in 5:
			await get_tree().process_frame
		_check(is_instance_valid(inst), "smoke %s alive" % path)
		inst.queue_free()
		await get_tree().process_frame
