extends Node
## 驗證時段推進新規則（2026-07-08 拍板）：只有戰鬥/小遊戲「完成」回到地圖/遊藝場才推進，
## 且經 SceneRouter.consume_period_advance() 播字卡；對話/移動/打工/存檔/休息不推進。
##
## a) perform_action("save") 後 period 不變；("rest")＝打坐，恰推進 1 時段（經字卡）＋回血
##    （2026-07-08 二批拍板：時段只在戰鬥/小遊戲後推進之後，打坐是玩家唯一主動跳時段手段）
## b) 模擬小遊戲完成：設 pending → SceneRouter.finish_minigame → go_to_map 換場 →
##    等消費完成 → period 恰 +1、旗標已清
## c) finish_minigame 本身即設 pending（併入 b 驗證，見上）
## d) TravelApp 移動、JobApp 打工不直接推進
##
## 掛在 root 下（同 TestRunner.gd 慣例）：go_to_map 換場前先把本節點脫離 current_scene，
## 換場時才不會被釋放。

func _ready() -> void:
	GameManager.new_game()
	await get_tree().process_frame
	get_tree().current_scene = null  # 脫離 current_scene，之後任何換場都不會釋放本測試節點

	# a) save 不推進；rest（打坐）回血＋經字卡恰推進 1 時段
	var ms := (load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene).instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var p0: int = GameManager.player.period
	ms.perform_action("save")
	if GameManager.player.period != p0:
		return _fail("save 不應推進時段，實 %d→%d" % [p0, GameManager.player.period])
	if GameManager.pending_period_advance:
		return _fail("save 不應設 pending_period_advance")
	GameManager.player.current_hp = 100
	ms.perform_action("rest")
	var expect_rest: int = (p0 + 1) % GameManager.TIME_PERIODS.size()
	var waited_rest := 0
	while GameManager.player.period != expect_rest and waited_rest < 3600:
		await get_tree().process_frame
		waited_rest += 1
	if GameManager.player.period != expect_rest:
		return _fail("打坐應恰推進 1 時段（經字卡），實 %d→%d（等了 %d 幀）" % [p0, GameManager.player.period, waited_rest])
	if GameManager.player.current_hp != 250:
		return _fail("打坐應回血 150，實 %d" % GameManager.player.current_hp)
	if GameManager.pending_period_advance:
		return _fail("打坐消費後旗標應已清")
	ms.queue_free()
	await get_tree().process_frame

	# d) TravelApp 移動不推進
	var travel = load("res://src/ui/menu/pages/TravelApp.gd").new()
	add_child(travel)
	await get_tree().process_frame
	GameManager.player.gold = 100
	var p1: int = GameManager.player.period
	var ok_mrt: bool = travel._pay_mrt("shrine")
	if not ok_mrt or GameManager.player.period != p1:
		return _fail("MRT 移動不應推進時段，實 %d→%d" % [p1, GameManager.player.period])
	travel.queue_free()
	await get_tree().process_frame

	# d) JobApp 打工不直接推進：_take_job 呼叫 SceneRouter.go_to_minigame 會真的換場，
	# 不在這裡直接呼叫；只驗證原本專供測試的「耗時」子函式已整個移除，沒有殘留呼叫路徑。
	var job = load("res://src/ui/menu/pages/JobApp.gd").new()
	if job.has_method("_start_job_time"):
		return _fail("JobApp._start_job_time 應已整個移除（打工不再直接推進時段）")
	job.free()

	# b+c) finish_minigame 設 pending → go_to_map 換場 → MapScreen._ready 消費 → period 恰 +1。
	var p3: int = GameManager.player.period
	GameManager.pending_period_advance = false
	SceneRouter._minigame_context = {}
	SceneRouter._active_minigame = "beggar_challenge"
	SceneRouter.finish_minigame({"id": "beggar_challenge", "win": true})
	if not GameManager.pending_period_advance:
		return _fail("finish_minigame（無 return_scene）應設 pending_period_advance")

	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		return _fail("finish_minigame 後未換回 MapScreen")
	# consume_period_advance() 一進入就立刻清旗標防重入（見 SceneRouter.gd 註解），
	# 所以不能拿 pending_period_advance 判斷字卡是否播完——改直接輪詢 period 本身變動。
	# 字卡全程（淡入0.4+停留1.2+淡出0.5≈2.1s）跑完才會真的 advance_time；輪詢到變動或逾時。
	var expect: int = (p3 + 1) % GameManager.TIME_PERIODS.size()
	var waited := 0
	while GameManager.player.period != expect and waited < 3600:
		await get_tree().process_frame
		waited += 1
	if GameManager.player.period != expect:
		return _fail("小遊戲完成回地圖應恰推進 1 時段，實 %d→%d（預期 %d，等了 %d 幀）" % [p3, GameManager.player.period, expect, waited])

	# e) finish_minigame 帶 return_scene（遊藝場內完成）：也要設 pending，回房後同樣消費 +1。
	var parlor_scene := "res://src/screens/MapScreen/environments/UndergroundParlor.tscn"
	var p4: int = GameManager.player.period
	GameManager.pending_period_advance = false
	SceneRouter._minigame_context = {"return_scene": parlor_scene}
	SceneRouter._active_minigame = "blackjack"
	SceneRouter.finish_minigame({"id": "blackjack", "win": true})
	if not GameManager.pending_period_advance:
		return _fail("finish_minigame（有 return_scene）也應設 pending_period_advance")
	var parlor: Node = await _wait_for_scene("UndergroundParlor")
	if parlor == null:
		return _fail("finish_minigame（return_scene）後未換回 UndergroundParlor")
	var expect2: int = (p4 + 1) % GameManager.TIME_PERIODS.size()
	var waited2 := 0
	while GameManager.player.period != expect2 and waited2 < 3600:
		await get_tree().process_frame
		waited2 += 1
	if GameManager.player.period != expect2:
		return _fail("遊藝場內小遊戲完成回房應恰推進 1 時段，實 %d→%d（預期 %d，等了 %d 幀）" % [p4, GameManager.player.period, expect2, waited2])

	# f) 中途放棄（MinigameBase._on_pause_leave 邏輯）不應設 pending——直接檢查該函式原始碼
	# 沒有 pending_period_advance 相關字樣，確認「完成」與「放棄」兩條路徑不共用推進邏輯。
	var pause_leave_src := FileAccess.get_file_as_string("res://src/screens/Minigames/MinigameBase.gd")
	var leave_fn_start := pause_leave_src.find("func _on_pause_leave")
	var leave_fn_body := pause_leave_src.substr(leave_fn_start, 700)
	if leave_fn_body.contains("pending_period_advance"):
		return _fail("_on_pause_leave（中途放棄）不應設 pending_period_advance")

	print("TEST PASS: 時段推進新規則(save/移動/打工不推進＋打坐主動+1＋小遊戲完成回地圖/遊藝場恰+1且清pending＋中途放棄不推進) OK")
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
