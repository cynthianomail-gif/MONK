extends Node
## headless 測試：小遊戲過場短片播放機制（規格 2026-07-04-minigame-overhaul-design.md §4）。
## 跑法：godot --headless res://test/TestMinigameCutscene.tscn
## 驗證：
##   1) 缺檔 id 立即返回 null，不擋流程（play_minigame_cutscene）
##   2) 有檔 id 能自然播完、停在最後一幀
##   3) 按滑鼠可跳過，跳過會先跳到最後一幀（不是直接消失）
##   4) 舊行為（skip_to_last=false，戰鬥/劇情過場）跳過仍維持「停在跳過當下那一幀」不受影響
##   5) dismiss_minigame_cutscene 淡出移除 overlay；overlay=null 時安全不做事
##   6) MinigameBase.show_result_panel 接上結尾過場：贏的 clip 存在時面板不會立即出現，
##      跳過過場後面板才疊上（過場在面板出現時移除）
##   7) 全程 headless 不崩潰
##   8) 支線觸發（QuestManager._start_stage_minigame，quests.json 的 trigger_minigame）
##      與 105 打工（JobApp._take_job）兩條啟動路徑都經過 SceneRouter.go_to_minigame，
##      即會播放 minigame_<id>_intro（2026-07-07 使用者回饋：這兩條路徑曾繞過開場短片）。

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await _test_missing_clip_returns_immediately()
	await _test_plays_and_stops_at_last_frame()
	await _test_mouse_click_skips_to_last_frame()
	await _test_legacy_skip_unaffected()
	await _test_dismiss_removes_overlay()
	await _test_dismiss_null_is_noop()
	await _test_result_panel_waits_for_end_cutscene()
	await _test_quest_trigger_path_plays_intro()
	await _test_jobapp_path_plays_intro()
	print("MINIGAME_CUTSCENE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

# ── 1) 缺檔 id 立即返回 null，不擋流程 ──
func _test_missing_clip_returns_immediately() -> void:
	var t0 := Time.get_ticks_msec()
	var overlay = await SceneRouter.play_minigame_cutscene("minigame_zz_no_such_game_intro")
	var dt := Time.get_ticks_msec() - t0
	_check(overlay == null, "missing clip dir -> play_minigame_cutscene returns null")
	_check(dt < 500, "missing clip -> returns near-instantly, not blocked (got %dms)" % dt)

# ── 2) 有檔 id：真正播完（不模擬跳過），停在最後一幀，回傳 overlay 仍在樹上 ──
func _test_plays_and_stops_at_last_frame() -> void:
	var overlay: CanvasLayer = await SceneRouter.play_minigame_cutscene("minigame_batting_intro")
	_check(overlay != null and is_instance_valid(overlay), "existing clip -> play_minigame_cutscene returns a live overlay")
	_check(overlay.layer == 128, "overlay uses CanvasLayer(128) same as play_battle_cutscene")
	var cs := _find_cutscene_screen(overlay)
	_check(cs != null, "overlay contains a CutsceneScreen instance")
	if cs != null:
		var total: int = cs._frames.size()
		_check(total == 61, "minigame_batting_intro has 61 frames (got %d)" % total)
		# 自然播完時 _idx 會遞增到 == total（迴圈判斷先加後比對再 return），
		# 但 frame_rect 的最後一次賦值停在 _frames[total-1]（最後一幀）沒被覆蓋，
		# 這才是「停在最後一幀」的實際契約（見 CutsceneScreen._process）。
		_check(cs._idx >= total - 1, "playback naturally reaches/passes the last frame index (got %d, last=%d)" % [cs._idx, total - 1])
		_check(cs.frame_rect.texture == cs._frames[total - 1], "frame_rect shows the last frame texture")
	await SceneRouter.dismiss_minigame_cutscene(overlay)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(overlay), "dismiss_minigame_cutscene frees the overlay")

# ── 3) 滑鼠點擊跳過：直接跳到最後一幀再結束（不是停在跳過當下那一幀） ──
func _test_mouse_click_skips_to_last_frame() -> void:
	var cs_scene: PackedScene = load("res://src/screens/CutsceneScreen/CutsceneScreen.tscn")
	var cs: Node = cs_scene.instantiate()
	add_child(cs)
	var finished_flag := {"v": false}
	cs.finished.connect(func() -> void: finished_flag.v = true)
	cs.play("minigame_darts_intro", true)   # skip_to_last = true
	var total: int = cs._frames.size()
	_check(total == 61, "minigame_darts_intro has 61 frames (got %d)" % total)
	_check(cs._idx == 0, "just started -> idx at 0 before skip")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	cs._input(ev)
	_check(finished_flag.v, "mouse click triggers finished immediately (skippable)")
	_check(cs._idx == total - 1, "skip jumps straight to last frame index (got %d/%d)" % [cs._idx, total - 1])
	_check(cs.frame_rect.texture == cs._frames[total - 1], "skip leaves frame_rect showing the last frame (not vanished)")
	cs.queue_free()
	await get_tree().process_frame

# ── 4) 舊呼叫端（skip_to_last 預設 false，戰鬥/劇情過場）：跳過仍停在跳過當下那一幀，行為不變 ──
func _test_legacy_skip_unaffected() -> void:
	var cs_scene: PackedScene = load("res://src/screens/CutsceneScreen/CutsceneScreen.tscn")
	var cs: Node = cs_scene.instantiate()
	add_child(cs)
	var finished_flag := {"v": false}
	cs.finished.connect(func() -> void: finished_flag.v = true)
	cs.play("break_food")   # skip_to_last 預設 false，維持既有戰鬥/劇情過場行為
	var idx_before: int = cs._idx
	# project.godot 的 "cancel" action 綁在 physical_keycode=KEY_ESCAPE（見 InputMap），
	# 用 physical_keycode 而非 keycode 建構事件，is_action_pressed("cancel") 才會成立。
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	cs._unhandled_input(ev)
	_check(finished_flag.v, "legacy path: confirm/cancel still finishes immediately")
	_check(cs._idx == idx_before, "legacy path: skip does NOT jump to last frame, stays where it was (got %d, was %d)" % [cs._idx, idx_before])
	cs.queue_free()
	await get_tree().process_frame

# ── 5) dismiss_minigame_cutscene 淡出移除 overlay ──
func _test_dismiss_removes_overlay() -> void:
	var overlay: CanvasLayer = await SceneRouter.play_minigame_cutscene("minigame_bowling_intro")
	_check(overlay != null, "bowling intro clip exists -> overlay created")
	if overlay != null:
		await SceneRouter.dismiss_minigame_cutscene(overlay)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not is_instance_valid(overlay), "overlay freed after dismiss_minigame_cutscene")

# ── 6) overlay = null 時 dismiss 安全不做事 ──
func _test_dismiss_null_is_noop() -> void:
	var t0 := Time.get_ticks_msec()
	await SceneRouter.dismiss_minigame_cutscene(null)
	var dt := Time.get_ticks_msec() - t0
	_check(dt < 200, "dismiss_minigame_cutscene(null) returns immediately, no crash (got %dms)" % dt)

# ── 7) MinigameBase.show_result_panel 接上結尾過場：
##      Darts 的 win/lose 兩支過場都已存在素材，win=true 時面板不會立即出現，
##      跳過過場（模擬滑鼠點擊）後面板疊在「停格的最後一幀」上（2026-07-07 定版：
##      過場留著當底不移除）；按「再玩一次」才淡出移除停格過場。 ──
func _test_result_panel_waits_for_end_cutscene() -> void:
	var gs = load("res://src/screens/Minigames/Darts.gd")
	var g = gs.new()
	g.auto_start = false
	get_tree().root.add_child(g)
	await get_tree().process_frame

	# suppress_end_cutscene 預設 false：真正遊戲流程一律播放結尾過場
	_check(g.suppress_end_cutscene == false, "suppress_end_cutscene defaults to false (real gameplay plays end cutscene)")

	g.show_result_panel("飛鏢", "神射手", [{"label": "得分", "value": "301"}], g.make_result({"win": true}))
	await get_tree().process_frame
	_check(not g.is_result_panel_open(), "darts win clip exists -> panel NOT open immediately (cutscene still playing)")

	# play_minigame_cutscene 先做 0.3s 淡入才建立 CutsceneScreen 節點（見 SceneRouter），
	# 用真實時間等待（沿用 TestCutscene.gd 對 tween/計時型過場的既有等法），確保淡入已過。
	await get_tree().create_timer(0.5, true).timeout
	var cs := _find_cutscene_screen(get_tree().current_scene)
	_check(cs != null, "ending cutscene overlay is present under current_scene while win clip plays")
	if cs != null:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		cs._input(ev)   # 模擬滑鼠點擊跳過

	# 跳過後停在最後一幀、面板隨即疊上；用真實時間上限（而非固定幀數）等待，
	# 避免 headless 幀率快慢造成誤判。
	var opened := false
	var t_wait0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_wait0 < 3000:
		await get_tree().process_frame
		if g.is_result_panel_open():
			opened = true
			break
	_check(opened, "panel opens shortly after the ending cutscene is skipped/finished")

	# 2026-07-07 定版：面板打開時，結尾過場「停在最後一幀留著當底」不移除
	# （結算視窗疊在 win/lose 停格上，不露出小遊戲畫面）。
	var backdrop := _find_cutscene_screen(get_tree().current_scene)
	_check(backdrop != null, "ending cutscene overlay STAYS as backdrop while the result panel shows")

	# 按「再玩一次」：面板關閉、停格過場淡出移除（0.3s fade），露出重開的新局。
	g._on_result_restart()
	var overlay_gone := false
	var t_wait1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_wait1 < 3000:
		await get_tree().process_frame
		if _find_cutscene_screen(get_tree().current_scene) == null:
			overlay_gone = true
			break
	_check(overlay_gone, "restart dismisses the frozen ending cutscene overlay")
	_check(not g.is_result_panel_open(), "restart closes the result panel")

	g.queue_free()
	await get_tree().process_frame

## ── 8a) 支線觸發路徑：QuestManager._start_stage_minigame 直接呼叫
##      SceneRouter.go_to_minigame(s.trigger_minigame, ctx)（QuestManager.gd:87）。
##      用 quests.json 真實資料（jie 支線，trigger_minigame=wooden_fish_rhythm，
##      無 dialogue 前置門檻依賴——直接呼叫 _start_stage_minigame 繞過 Dialogic 對話段，
##      只驗證「呼叫後會經過 go_to_minigame 並播放 intro 短片」這條路徑本身）。
##      這兩個是全檔最後兩個測試：go_to_minigame 會實際 change_scene_to_file，
##      之後不會再有測試依賴目前的場景樹。
func _test_quest_trigger_path_plays_intro() -> void:
	var q: Dictionary = QuestManager._quests.get("jie", {})
	_check(not q.is_empty(), "quests.json has 'jie' quest data with trigger_minigame")
	if q.is_empty():
		return
	var stage := 0
	_check(q.stages[stage].get("trigger_minigame", "") == "wooden_fish_rhythm",
		"jie stage 0 triggers wooden_fish_rhythm (sanity check on fixture)")
	QuestManager._start_stage_minigame("jie", stage, q)
	await get_tree().process_frame
	_check(SceneRouter._active_minigame == "wooden_fish_rhythm",
		"QuestManager._start_stage_minigame routes through SceneRouter.go_to_minigame (active_minigame set)")
	# go_to_minigame 換場後會播 minigame_wooden_fish_rhythm_intro（素材存在，見 assets/cutscenes/）；
	# 用真實時間等待場景切換＋淡入跑完，確認過場 overlay 真的出現在新場景樹下。
	var found_overlay := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		var cs := _find_cutscene_screen(get_tree().root)
		if cs != null:
			found_overlay = true
			break
	_check(found_overlay, "quest trigger path: minigame_wooden_fish_rhythm_intro overlay appears after go_to_minigame")

## ── 8b) 105 打工路徑：JobApp._take_job 直接呼叫 SceneRouter.go_to_minigame(minigame_id)
##      （JobApp.gd:44，beggar_challenge）。
func _test_jobapp_path_plays_intro() -> void:
	var job_script: GDScript = load("res://src/ui/menu/pages/JobApp.gd")
	_check(job_script != null, "JobApp.gd loads")
	if job_script == null:
		return
	var job: VBoxContainer = job_script.new()
	get_tree().root.add_child(job)
	await get_tree().process_frame
	job._take_job("beggar_challenge")
	await get_tree().process_frame
	_check(SceneRouter._active_minigame == "beggar_challenge",
		"JobApp._take_job routes through SceneRouter.go_to_minigame (active_minigame set)")
	var found_overlay := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		var cs := _find_cutscene_screen(get_tree().root)
		if cs != null:
			found_overlay = true
			break
	_check(found_overlay, "JobApp path: minigame_beggar_challenge_intro overlay appears after go_to_minigame")
	if is_instance_valid(job):
		job.queue_free()

## 在指定根節點（或整個 current_scene）底下找第一個「像 CutsceneScreen」的節點
## （有 play 方法＋finished 訊號），供驗證 overlay 內容/確認過場已移除用。
func _find_cutscene_screen(root: Node) -> Node:
	if root == null:
		return null
	if root.has_method("play") and root.has_signal("finished"):
		return root
	for c in root.get_children():
		var found := _find_cutscene_screen(c)
		if found != null:
			return found
	return null
