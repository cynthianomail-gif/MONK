extends Node
## 對話回想 log（backlog）headless 驗證：
##  a) 啟動 cherry_first_meeting、推進數個 Text 節點 → History 收到條目（說話者+文字非空）
##  b) 模擬 Tab → 面板開啟（visible）；再 Tab → 關閉
##  c) 面板開啟時，對 Dialogic 送出推進事件不會讓 timeline 前進（current_event_idx 不變）
##  d) GameManager.new_game() 清空 log
## 以 main scene 跑，autoload（Dialogic / GameManager）皆在線。
## 跑法：Godot --headless res://test/TestDialogueHistory.tscn

var ok := true

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
	else:
		push_error("  [FAIL] " + msg)
		ok = false

func _tab_event() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	return ev

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # DialogueHistoryPanel 用 call_deferred add_child，多等一幀

	var panel: CanvasLayer = GameManager.dialogue_history
	if panel == null:
		_check(false, "GameManager.dialogue_history 已建立")
		print("DIALOGUE_HISTORY_TEST: HAS FAILURES")
		get_tree().quit(1)
		return
	_check(panel is CanvasLayer, "DialogueHistoryPanel 是 CanvasLayer")
	_check(Dialogic.has_subsystem("History"), "Dialogic History 子系統存在")
	_check(Dialogic.History.simple_history_enabled, "simple_history_enabled 已由 GameManager 啟用")

	await _test_history_collects_entries(panel)
	await _test_tab_toggle(panel)
	await _test_open_blocks_advance(panel)
	_test_new_game_clears(panel)

	print("DIALOGUE_HISTORY_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)


## a) 啟動 timeline、推進 3 個 Text 節點（join / Cherry / Wujie / Cherry，在第一個 Choice 之前）
## → History 收到條目，說話者與文字皆非空。
func _test_history_collects_entries(panel: CanvasLayer) -> void:
	Dialogic.History.simple_history_content = []
	panel.entries.clear()
	panel._last_seen_count = 0

	# Dialogic.start() 內部已把 layout 掛到 root（create_layout），這裡不重複 add_child。
	Dialogic.start("cherry_first_meeting")
	await get_tree().process_frame

	# 推進 3 次：join(不算Text) 已在 start 時處理；接著 3 句 Text(Cherry/Wujie/Cherry) 在 Choice 之前。
	for i in range(3):
		await get_tree().create_timer(0.05).timeout
		if Dialogic.current_timeline != null:
			Dialogic.handle_next_event()
		await get_tree().process_frame

	await get_tree().process_frame

	var raw: Array = Dialogic.History.get_simple_history()
	_check(raw.size() > 0, "Dialogic.History.simple_history_content 有收到條目（實得 %d 筆）" % raw.size())

	panel._sync_from_history()
	_check(panel.entries.size() > 0, "DialogueHistoryPanel.entries 有同步到條目（實得 %d 筆）" % panel.entries.size())

	var found_speaker := false
	var found_text := false
	for e in panel.entries:
		if String(e.get("speaker", "")) != "":
			found_speaker = true
		if String(e.get("text", "")) != "":
			found_text = true
	_check(found_speaker, "至少一筆條目說話者非空（例如 Cherry/無戒）")
	_check(found_text, "至少一筆條目台詞文字非空")

	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)  # skip_ending：同步清掉 current_timeline，不必等 ending timeline 播完
	await get_tree().process_frame


## b) 非對話中按 Tab 無反應；對話中按 Tab → 開啟；再按 Tab → 關閉。
func _test_tab_toggle(panel: CanvasLayer) -> void:
	panel.visible = false
	_check(Dialogic.current_timeline == null, "前置：目前無對話進行中")
	panel._input(_tab_event())
	_check(not panel.visible, "非對話中按 Tab：面板不開啟")

	Dialogic.start("cherry_first_meeting")
	await get_tree().process_frame

	panel._input(_tab_event())
	_check(panel.visible, "對話中按 Tab：面板開啟")

	panel._input(_tab_event())
	_check(not panel.visible, "再按 Tab：面板關閉")

	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)  # skip_ending：同步清掉 current_timeline，不必等 ending timeline 播完
	await get_tree().process_frame


## c) 面板開啟期間，Dialogic 的推進呼叫不應該讓 timeline 的 current_event_idx 前進。
## DialogueHistoryPanel 本身不攔截 Dialogic 的內部呼叫，但 _input 對推進鍵有 set_input_as_handled，
## 這裡直接驗證：面板開啟時，模擬「按下推進鍵」的 _input 事件會被面板吞掉（handled），
## 不會傳到 Dialogic 的輸入層（用 get_viewport 的 is_input_handled 佐證 + current_event_idx 不變）。
func _test_open_blocks_advance(panel: CanvasLayer) -> void:
	Dialogic.start("cherry_first_meeting")
	await get_tree().process_frame

	panel._input(_tab_event())
	_check(panel.visible, "前置：面板已開啟")

	var idx_before: int = Dialogic.current_event_idx
	# 面板開啟時模擬滑鼠左鍵（一般推進對話的操作）。面板的 _input 在 Dialogic 的文字框輸入層
	# 之前攔截並 set_input_as_handled，Dialogic 收不到、timeline 不應前進。
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_tree().root.get_viewport().push_input(click)
	await get_tree().process_frame
	_check(Dialogic.current_event_idx == idx_before, "面板開啟期間，current_event_idx 未前進（推進被面板擋下）")

	panel._input(_tab_event())
	_check(not panel.visible, "收尾：面板關閉")
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)  # skip_ending：同步清掉 current_timeline，不必等 ending timeline 播完
	await get_tree().process_frame


## d) GameManager.new_game() 清空 log。
func _test_new_game_clears(panel: CanvasLayer) -> void:
	_check(panel.entries.size() > 0, "前置：目前 log 內有條目（清空前）")
	GameManager.new_game()
	_check(panel.entries.is_empty(), "new_game() 後 DialogueHistoryPanel.entries 清空")
	_check(Dialogic.History.get_simple_history().is_empty(), "new_game() 後 Dialogic simple_history_content 也清空")
