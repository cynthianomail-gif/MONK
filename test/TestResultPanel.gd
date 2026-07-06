extends Node
## headless 測試：MinigameBase 共用結算面板（P1 期）。
## 驗證：面板出現／兩鈕行為／finish 只在「離開」時觸發／
## restart 可連續多輪且不重複發獎勵。
## 跑法：Godot --headless res://test/TestResultPanel.tscn
##
## 這支測試跑在完整專案下（含 SceneRouter autoload），所以 MinigameBase.finish()
## 一定會走 SceneRouter.finish_minigame() 那條路（不是測試用的直接訊號分支）；
## 因此监听 SceneRouter.minigame_finished(id, result) 來判定 finish 是否真的觸發，
## 而不是 MinigameBase 自己的 minigame_finished（那個訊號只有在沒有 SceneRouter
## autoload 時才會發出，本測試環境不會走到）。

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_panel_shows_and_has_two_buttons()
	await _test_restart_no_double_award()
	await _test_leave_triggers_finish_once()
	await _test_multiple_restarts_then_leave_uses_last_result()
	print("RESULT_PANEL_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _make_game() -> Node:
	# 用化緣（BeggarChallenge）當白老鼠：純邏輯簡單、restart 已實作。
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	var g = gs.new()
	g.auto_start = false
	# 本測試驗證的是面板本身的同步行為（show_result_panel 呼叫後下一幀就要開啟），
	# 與結尾過場短片（minigame_beggar_challenge_win 素材已存在，會實際播放數秒）無關，
	# 故關閉過場播放，行為與 P1 期實作時一致；過場播放邏輯另見 test/TestMinigameCutscene.gd。
	g.suppress_end_cutscene = true
	get_tree().root.add_child(g)
	return g

func _test_panel_shows_and_has_two_buttons() -> void:
	var g = _make_game()
	g._build_scene()
	_check(not g.is_result_panel_open(), "panel closed before show_result_panel")
	g.show_result_panel("化緣", "功德圓滿", [{"label": "功德金", "value": "100"}], g.make_result({"score": 100, "win": true, "gold": 100}))
	await get_tree().process_frame
	_check(g.is_result_panel_open(), "panel open after show_result_panel")
	_check(g._result_buttons.size() == 2, "panel has exactly 2 buttons (got %d)" % g._result_buttons.size())
	_check(g._result_buttons[0].text == "再玩一次", "button0 = 再玩一次")
	_check(g._result_buttons[1].text == "離開", "button1 = 離開 (default label)")
	g.queue_free()
	await get_tree().process_frame

## restart 一輪不應觸發 finish/SceneRouter 訊號；面板應關閉、遊戲繼續跑。
func _test_restart_no_double_award() -> void:
	var g = _make_game()
	g._build_scene()
	var got_finish := false
	var conn := func(_id, _r): got_finish = true
	SceneRouter.minigame_finished.connect(conn)
	g.score = 500
	var r: Dictionary = g.build_result()
	g.show_result_panel("化緣", "功德圓滿", [{"label": "功德金", "value": "500"}], r)
	await get_tree().process_frame
	g._result_buttons[0].pressed.emit()   # 再玩一次
	await get_tree().process_frame
	_check(not g.is_result_panel_open(), "panel closes after restart pressed")
	_check(not got_finish, "restart must NOT call finish()/emit SceneRouter.minigame_finished")
	_check(g.score == 0, "restart resets score to 0 (got %d)" % g.score)
	_check(g._running == true, "restart resumes game loop (_running=true)")
	SceneRouter.minigame_finished.disconnect(conn)
	g.queue_free()
	await get_tree().process_frame

## 離開才呼叫 finish；SceneRouter.finish_minigame 套用獎勵後發出 minigame_finished。
func _test_leave_triggers_finish_once() -> void:
	var g = _make_game()
	g._build_scene()
	var results: Array = []
	var conn := func(_id, res): results.append(res)
	SceneRouter.minigame_finished.connect(conn)
	g.score = 300
	var r: Dictionary = g.build_result()
	g.show_result_panel("化緣", "功德圓滿", [{"label": "功德金", "value": "300"}], r)
	await get_tree().process_frame
	g._result_buttons[1].pressed.emit()   # 離開
	await get_tree().process_frame
	_check(results.size() == 1, "leave triggers finish exactly once (got %d)" % results.size())
	if results.size() == 1:
		_check(int(results[0].gold) == 300, "finish result carries gold=300 (got %d)" % int(results[0].gold))
	# 重複呼叫離開的 finish（重入保護：_finished 旗標已在第一次 finish() 設 true）
	g.finish(g.make_result({"gold": 999}))
	await get_tree().process_frame
	_check(results.size() == 1, "finish() re-entry guarded, no duplicate award (still %d)" % results.size())
	SceneRouter.minigame_finished.disconnect(conn)
	g.queue_free()
	await get_tree().process_frame

## 連續兩次「再玩一次」再「離開」：獎勵只以最後一次的 result 為準。
func _test_multiple_restarts_then_leave_uses_last_result() -> void:
	var g = _make_game()
	g._build_scene()
	var results: Array = []
	var conn := func(_id, res): results.append(res)
	SceneRouter.minigame_finished.connect(conn)
	# 第一局：假分數 100
	g.score = 100
	g.show_result_panel("化緣", "尚可", [{"label": "功德金", "value": "100"}], g.build_result())
	await get_tree().process_frame
	g._result_buttons[0].pressed.emit()   # 再玩一次 #1
	await get_tree().process_frame
	_check(results.is_empty(), "still no finish after 1st restart")
	# 第二局：假分數 250（restart 已把 score 歸零，這裡模擬玩完第二局）
	g.score = 250
	g.show_result_panel("化緣", "功德圓滿", [{"label": "功德金", "value": "250"}], g.build_result())
	await get_tree().process_frame
	g._result_buttons[0].pressed.emit()   # 再玩一次 #2
	await get_tree().process_frame
	_check(results.is_empty(), "still no finish after 2nd restart")
	# 第三局：假分數 777，這次離開
	g.score = 777
	var r3: Dictionary = g.build_result()
	g.show_result_panel("化緣", "圓滿", [{"label": "功德金", "value": "777"}], r3)
	await get_tree().process_frame
	g._result_buttons[1].pressed.emit()   # 離開
	await get_tree().process_frame
	_check(results.size() == 1, "exactly one finish after 2 restarts + 1 leave (got %d)" % results.size())
	if results.size() == 1:
		_check(int(results[0].gold) == 777, "final result uses LAST round's score=777 (got %d)" % int(results[0].gold))
	SceneRouter.minigame_finished.disconnect(conn)
	g.queue_free()
	await get_tree().process_frame
