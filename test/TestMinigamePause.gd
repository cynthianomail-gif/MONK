extends Node
## headless 測試：MinigameBase 共用 ESC 暫停頁（規格：全小遊戲 ESC 暫停頁）。
## 跑法：Godot --headless res://test/TestMinigamePause.tscn
## 驗證：
##   1) ESC(cancel action) 開啟暫停頁：paused=true、overlay 可見
##   2) 「繼續」：paused=false、overlay 關閉
##   3) 「再試一次」：走 restart()（不觸發 finish/SceneRouter.minigame_finished）
##   4) 「離開」：不套用獎勵，直接返回（不同於結算面板離開）
##   5) 結算面板開著時 ESC 不觸發暫停
##   6) 暫停中再按 cancel 恢復（toggle）
##
## 這支測試跑在完整專案下（含 SceneRouter autoload），行為判定方式比照
## TestResultPanel.gd：離開/finish 是否觸發用 SceneRouter.minigame_finished 訊號判定。

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await _test_esc_opens_pause_freezes_tree()
	await _test_resume_closes_and_unpauses()
	await _test_restart_from_pause_no_award()
	await _test_leave_from_pause_no_reward_no_double_finish()
	await _test_esc_ignored_while_result_panel_open()
	await _test_esc_toggles_resume()
	print("MINIGAME_PAUSE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	# 保險：測試本身可能中途留下 paused=true（斷言失敗中斷流程），收尾前強制復原，
	# 避免影響同一個 headless 進程裡其他還沒跑的測試（如果未來被串接執行）。
	get_tree().paused = false
	get_tree().quit(0 if ok else 1)

func _make_game() -> Node:
	# 用化緣（BeggarChallenge）當白老鼠，理由同 TestResultPanel.gd：純邏輯簡單、restart 已實作。
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	var g = gs.new()
	g.auto_start = false
	g.suppress_end_cutscene = true
	get_tree().root.add_child(g)
	return g

func _cancel_event() -> InputEventKey:
	# project.godot 的 "cancel" action 綁在 physical_keycode=KEY_ESCAPE。
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev

## ── 1) ESC 開暫停頁：paused=true，overlay 可見 ──
func _test_esc_opens_pause_freezes_tree() -> void:
	var g = _make_game()
	g._build_scene()
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "pause menu closed before ESC")
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(g.is_paused_menu_open(), "ESC opens pause menu")
	_check(get_tree().paused == true, "get_tree().paused becomes true after ESC")
	_check(g._pause_buttons.size() == 3, "pause menu has 3 buttons (got %d)" % g._pause_buttons.size())
	_check(g._pause_buttons[0].text == "繼續", "button0 = 繼續")
	_check(g._pause_buttons[1].text == "再試一次", "button1 = 再試一次")
	_check(g._pause_buttons[2].text == "離開", "button2 = 離開")
	# 收尾：手動關閉，恢復 paused=false，不污染下一個測試。
	g._close_pause_menu()
	g.queue_free()
	await get_tree().process_frame

## ── 2) 「繼續」：paused=false、overlay 關閉 ──
func _test_resume_closes_and_unpauses() -> void:
	var g = _make_game()
	g._build_scene()
	await get_tree().process_frame
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(g.is_paused_menu_open(), "pause menu open before resume")
	g._pause_buttons[0].pressed.emit()   # 繼續
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "pause menu closed after 繼續")
	_check(get_tree().paused == false, "get_tree().paused restored to false after 繼續")
	g.queue_free()
	await get_tree().process_frame

## ── 3) 「再試一次」：走 restart()，不觸發 finish ──
func _test_restart_from_pause_no_award() -> void:
	var g = _make_game()
	g._build_scene()
	g.score = 250
	var got_finish := false
	var conn := func(_id, _r): got_finish = true
	SceneRouter.minigame_finished.connect(conn)
	await get_tree().process_frame
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(g.is_paused_menu_open(), "pause menu open before restart")
	g._pause_buttons[1].pressed.emit()   # 再試一次
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "pause menu closed after 再試一次")
	_check(get_tree().paused == false, "get_tree().paused restored to false after 再試一次")
	_check(not got_finish, "再試一次 must NOT call finish()/emit SceneRouter.minigame_finished")
	_check(g.score == 0, "再試一次 resets score to 0 via restart() (got %d)" % g.score)
	SceneRouter.minigame_finished.disconnect(conn)
	g.queue_free()
	await get_tree().process_frame

## ── 4) 「離開」：中途放棄，不套用獎勵；仍會經過 SceneRouter（context 清乾淨），
##      但傳出的 result 是空 dict／不含本局分數，驗證「無獎勵」語意。──
func _test_leave_from_pause_no_reward_no_double_finish() -> void:
	var g = _make_game()
	g._build_scene()
	g.score = 999   # 中途累積的分數：離開不應該把它當獎勵送出
	SceneRouter._minigame_context = {"quest_win": {"gold": 500}, "quest_lose": {"gold": 0}}
	var gold_before: int = GameManager.player.gold
	await get_tree().process_frame
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(g.is_paused_menu_open(), "pause menu open before leave")
	g._pause_buttons[2].pressed.emit()   # 離開
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "pause menu closed after 離開")
	_check(get_tree().paused == false, "get_tree().paused restored to false after 離開")
	_check(SceneRouter._minigame_context.is_empty(), "leaving via pause menu clears SceneRouter._minigame_context (no pollution for next game)")
	_check(GameManager.player.gold == gold_before, "leaving via pause menu does NOT award gold (got %d, was %d)" % [GameManager.player.gold, gold_before])
	if is_instance_valid(g):
		g.queue_free()
	await get_tree().process_frame

## ── 5) 結算面板開著時 ESC 不應觸發暫停 ──
func _test_esc_ignored_while_result_panel_open() -> void:
	var g = _make_game()
	g._build_scene()
	await get_tree().process_frame
	g.show_result_panel("化緣", "功德圓滿", [{"label": "功德金", "value": "100"}], g.make_result({"score": 100, "win": true, "gold": 100}))
	await get_tree().process_frame
	_check(g.is_result_panel_open(), "result panel open (setup)")
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "ESC does NOT open pause menu while result panel is open")
	_check(get_tree().paused == false, "get_tree().paused stays false (result panel doesn't pause tree)")
	g.queue_free()
	await get_tree().process_frame

## ── 6) 暫停中再按一次 cancel：恢復（toggle 語意，走 _PauseWatcher 路徑）──
func _test_esc_toggles_resume() -> void:
	var g = _make_game()
	g._build_scene()
	await get_tree().process_frame
	g._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(g.is_paused_menu_open(), "pause menu open after 1st ESC")
	# 暫停中 MinigameBase 本體收不到 _unhandled_input（PROCESS_MODE_INHERIT 被凍結），
	# 真正生效的是 _PauseWatcher（process_mode=ALWAYS）；直接呼叫它模擬暫停中的按鍵。
	_check(g._pause_watcher != null and is_instance_valid(g._pause_watcher), "_PauseWatcher exists once pause menu has been opened")
	g._pause_watcher._unhandled_input(_cancel_event())
	await get_tree().process_frame
	_check(not g.is_paused_menu_open(), "2nd ESC (via _PauseWatcher) closes pause menu")
	_check(get_tree().paused == false, "get_tree().paused restored to false after 2nd ESC")
	g.queue_free()
	await get_tree().process_frame
