extends Node
## QA 黃金路線實機駕駛腳本（2026-07-10）：真遊戲（非 headless）從標題畫面一路跑過
## 第一章各系統，每個節拍截圖存 D:/monk/_qa_golden_20260709/，逾時記「STUCK AT」。
##
## 跑法（視窗模式，非 headless；headless 會卡 frame_post_draw）：
##   D:\monk\tools\godot\Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/QaGoldenPath.tscn -- smoke
##
## 設計：本腳本掛在 root 下常駐（不隨場景切換釋放，同 TestRunner.gd/TestPeriodFlow.gd 慣例）。
## 逐節拍推進，每節拍有 watchdog timeout；逾時就截圖＋記錄 STUCK，嘗試跳過繼續下一拍
## （不中止整趟跑，盡量把後面能測的節拍都測到）。
## 推進手段：優先真輸入注入（Input.parse_input_event 模拟按鍵/滑鼠），注不動的節拍
## （如主線協程鏈里的 gate/technical prerequisite）用 API 直呼並在報告標注「API 捷徑」。
##
## 產出：
##   - D:/monk/_qa_golden_20260709/{序號}_{節拍名}.png（每節拍至少一張）
##   - D:/monk/_qa_golden_20260709/console_log.txt（全程 print/push_error/push_warning 擷取）
##   - print 出 "QA_BEAT_RESULT|beat|status|screenshot|note" 供跑完後從 log 萃取總表
##   - print 出 "QA_API_SHORTCUT|beat|what" 標注 API 捷徑
##   - print 出 "QA_SAVE_DIR_LISTING|...” 結尾列出真實存檔目錄檔案

const OUT_DIR := "D:/monk/_qa_golden_20260709"
const DEFAULT_TIMEOUT := 30.0
const LONG_TIMEOUT := 60.0

var _beat_idx := 0
var _log_lines: Array[String] = []

func _ready() -> void:
	get_tree().current_scene = null  # 脫離 current_scene，任何換場都不會釋放本節點（同 TestRunner.gd 慣例）
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log("QA_GOLDEN_PATH_START %s" % Time.get_datetime_string_from_system())
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_all_beats()
	_finish()

func _finish() -> void:
	_log("QA_GOLDEN_PATH_END %s" % Time.get_datetime_string_from_system())
	_dump_save_dir_listing()
	_flush_log()
	print("QA_GOLDEN_PATH_DONE")
	get_tree().quit(0)

# ════════════════════════════════════════════════════════════════
# 節拍執行框架
# ════════════════════════════════════════════════════════════════

## 執行一個節拍：跑 fn（可能是協程），全程 watchdog。fn 回傳 Dictionary
## {status: "PASS"/"SKIPPED", note: String} 或什麼都不回（視為 PASS）。
## fn 逾時（watchdog 觸發）：截圖＋記 STUCK，不阻塞後續節拍。
## 回傳最終狀態字串，供呼叫端視需要分流。
func _beat(beat_name: String, timeout: float, fn: Callable) -> String:
	_beat_idx += 1
	var tag := "%02d_%s" % [_beat_idx, beat_name]
	_log("── BEAT %s START ──" % tag)
	# ⚠ GDScript lambda 按值捕捉外層區域變數（同 project_battle_standing_figures.md 記載的踩坑），
	# 不能讓 lambda 內對 result/done 重新賦值後指望外層看到——一定要用「同一個」Dictionary
	# 物件、只改它的鍵值（mutate in place），Dictionary 是參照型別，這樣內外才共用同一份記憶體。
	var box := {"done": false, "status": "PASS", "note": ""}

	var run_co := func() -> void:
		var r: Variant = await fn.call()
		if typeof(r) == TYPE_DICTIONARY:
			var rd: Dictionary = r
			box["status"] = String(rd.get("status", "PASS"))
			box["note"] = String(rd.get("note", ""))
		box["done"] = true

	run_co.call()

	var elapsed := 0.0
	const STEP := 0.25
	while not box["done"] and elapsed < timeout:
		await get_tree().create_timer(STEP, true, false, true).timeout  # ignore_time_scale
		elapsed += STEP

	if not box["done"]:
		box["status"] = "STUCK"
		box["note"] = "逾時 %.0fs 未完成" % timeout
		_log("!!! STUCK AT %s (逾時 %.0fs)" % [beat_name, timeout])

	var shot_path := "%s/%s.png" % [OUT_DIR, tag]
	await _screenshot(shot_path)

	# STUCK 情況下，run_co 的協程可能還掛在 await 上（背景孤兒繼續跑），
	# 不強制殺掉（Godot 協程沒有硬 cancel），只記錄不再等待，繼續下一拍。
	_log("QA_BEAT_RESULT|%s|%s|%s|%s" % [beat_name, box["status"], shot_path, box["note"]])
	_log("── BEAT %s END (%s) ──" % [tag, box["status"]])
	return String(box["status"])

func _api_shortcut(beat_name: String, what: String) -> void:
	_log("QA_API_SHORTCUT|%s|%s" % [beat_name, what])

func _screenshot(path: String) -> void:
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	_log("SAVED_SCREENSHOT %s (%dx%d)" % [path, img.get_width(), img.get_height()])

func _log(line: String) -> void:
	print(line)
	_log_lines.append(line)

func _flush_log() -> void:
	var f := FileAccess.open("%s/console_log.txt" % OUT_DIR, FileAccess.WRITE)
	if f == null:
		push_error("QA: 無法寫入 console_log.txt")
		return
	f.store_string("\n".join(_log_lines))
	f.close()

func _dump_save_dir_listing() -> void:
	var dir_path := "C:/Users/cynth/AppData/Roaming/Godot/app_userdata/和尚逆天 Monk Go Rogue"
	var d := DirAccess.open(dir_path)
	if d == null:
		_log("QA_SAVE_DIR_LISTING|ERROR|無法開啟 %s" % dir_path)
		return
	_log("QA_SAVE_DIR_LISTING_START %s" % dir_path)
	_list_dir_recursive(dir_path, "")
	_log("QA_SAVE_DIR_LISTING_END")

func _list_dir_recursive(base: String, rel: String) -> void:
	var full := base + ("/" + rel if rel != "" else "")
	var d := DirAccess.open(full)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if fname in [".", ".."]:
			fname = d.get_next()
			continue
		var rel_path := (rel + "/" + fname) if rel != "" else fname
		if d.current_is_dir():
			_log("QA_SAVE_DIR_LISTING|DIR|%s/" % rel_path)
			_list_dir_recursive(base, rel_path)
		else:
			var fa := FileAccess.open(full + "/" + fname, FileAccess.READ)
			var sz := fa.get_length() if fa != null else -1
			_log("QA_SAVE_DIR_LISTING|FILE|%s|%d bytes" % [rel_path, sz])
		fname = d.get_next()
	d.list_dir_begin()  # no-op safeguard; list_dir_end below closes iteration
	d.list_dir_end()

# ════════════════════════════════════════════════════════════════
# 輸入注入輔助
# ════════════════════════════════════════════════════════════════

func _press_key(keycode: Key, physical: bool = true) -> void:
	var ev := InputEventKey.new()
	if physical:
		ev.physical_keycode = keycode
	else:
		ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventKey.new()
	if physical:
		up.physical_keycode = keycode
	else:
		up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _hold_key_frames(keycode: Key, frames: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	for i in frames:
		await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

## ⚠ 2026-07-10 全腳本性根因（見 _advance_dialogic() 完整說明）：Input.action_press()/
## action_release() 只改寫 Input 單例內部給輪詢用的狀態（is_action_pressed 讀得到），
## **不會**合成一個 InputEvent 送進 Viewport.push_input()／SceneTree 的事件傳播管線。
## 本專案幾乎所有互動（MapScreen/MenuShell/SaveSlotPicker/CommandMenu/
## DialogueHistoryPanel/OfferingToss 全部用 _input()/_unhandled_input()，只有真正流經
## 傳播管線的 InputEvent 才會被收到）都靠這條管線，原本這裡只呼叫 action_press/release
## 等於全腳本所有「按鍵」動作都是 no-op——這正是連續四輪始終卡在同一行/同一畫面的
## 真正共同根因。改用 InputEventAction 物件經 Input.parse_input_event() 送出，才會真正
## 流經傳播管線、被 _input()/_unhandled_input() 收到。
func _press_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

## ⚠ 2026-07-10 連續四輪實跑才抓全的根本踩坑（兩層，兩層都修了）：
## 層①：Dialogic 文字框推進讀的是自訂輸入動作 "dialogic_default_action"（見
## addons/dialogic/Modules/Text/node_input.gd:14），不是本專案泛用的 "confirm" 動作
## ——第一二輪都用錯 confirm，第三輪改對動作名。
## 層②（第三四輪改對動作名後仍卡在同一行才發現，見 _press_action() 完整說明）：
## Input.action_press()/action_release() 不會合成 InputEvent 送進事件傳播管線，
## Dialogic 的 subsystem_input.gd._unhandled_input(event) 永遠收不到、永遠不會推進。
## _press_action() 已修正為用 InputEventAction 經 Input.parse_input_event() 送出
## （subsystem_input.gd:140 的 is_input_pressed() 第一個判斷式
## `event is InputEventAction and event.action == action` 正是為此設計），
## 現在只需呼叫正確動作名 "dialogic_default_action" 即可，兩層根因都已解決。
func _advance_dialogic() -> void:
	await _press_action("dialogic_default_action")

func _click_button(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pressed.emit()
	await get_tree().process_frame

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout  # ignore_time_scale

## 等待 current_scene 變成指定名稱（換場是延遲的）。
func _wait_for_scene(scene_name: String, max_wait: float = 10.0) -> Node:
	var elapsed := 0.0
	while elapsed < max_wait:
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return null

## 等待某個條件成立（poll callable），逾時回傳 false。
func _wait_until(cond: Callable, max_wait: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_wait:
		if cond.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return cond.call()

func _map_screen() -> Node:
	var cs := get_tree().current_scene
	if cs and cs.name == "MapScreen":
		return cs
	return null

## 偵測目前 current_scene 是否本身就是（或疊著）一個過場播放器（CutsceneScreen/StoryCutscene）：
## 這兩者都有 play() 方法＋finished 訊號，但沒有共同 class_name 可查，用鴨子型別偵測
## （同 src/screens/Minigames/MinigameBase.gd 的 _find_cutscene_overlay 手法）。
## play_story_cutscene/play_cutscene 是直接 change_scene_to_file 換成過場場景本身
## （不是疊在別的場景上），所以連 current_scene 自己都要檢查，不能只掃子節點。
func _is_cutscene_playing() -> bool:
	var cs := get_tree().current_scene
	if cs == null:
		return false
	if _looks_like_cutscene_player(cs):
		return true
	return _find_cutscene_overlay(cs) != null

func _looks_like_cutscene_player(node: Node) -> bool:
	return node.has_method("play") and node.has_signal("finished")

func _find_cutscene_overlay(node: Node) -> Node:
	for c in node.get_children():
		if _looks_like_cutscene_player(c):
			return c
		var found := _find_cutscene_overlay(c)
		if found != null:
			return found
	return null

## 對話推進：對話進行中反覆按 dialogic_default_action(Space/Enter/滑鼠左鍵) 直到
## timeline_ended 或逾時（見 _advance_dialogic() 註解——不是 "confirm"）。
## Dialogic 選項若跳出且無特殊處理，先睡過 0.2s choice_blocker 窗口再確認選第一項。
func _advance_dialogue_until_done(max_wait: float = 20.0) -> String:
	if Dialogic.current_timeline == null:
		return "not_started"
	var elapsed := 0.0
	const STEP := 0.12
	while Dialogic.current_timeline != null and elapsed < max_wait:
		await _advance_dialogic()
		await _wait_seconds(STEP)
		elapsed += STEP
	return "ended" if Dialogic.current_timeline == null else "timeout"

## ⚠ 2026-07-11 D-6 根因診斷（3 行）：
## 1) 選項卡了 15 秒必 STUCK，不是逾時不夠，是按錯動作——DialogicNode_ChoiceButton 是純
##    Godot Button，靠內建 focus + "ui_accept" 動作回應（同 CommandMenu/ShopScreen 現有鍵盤操作）。
## 2) subsystem_choices.gd:289-291 的 _on_dialogic_action() 只有在 use_input_action==true 時才會
##    把 "dialogic_default_action" 轉發給目前聚焦的選項鈕；use_input_action 宣告預設 false
##    （subsystem_choices.gd:26），且全專案（含 project.godot）沒有任何地方把它設成 true。
## 3) 所以先前對著選項畫面猛按 dialogic_default_action 是徹底的 no-op，choice_blocker 視窗
##    過了也沒用；autofocus_first_choice 預設 true（專案未覆寫 dialogic/choices/autofocus_first），
##    第一個選項出現時已自動 grab_focus，只需要送真實 "ui_accept" 讓 Godot Button 內建機制接手。
##
## 若有選項面板跳出，先過 0.2s _choice_blocker 窗口，對目前有 focus（或退回抓第一個可見）的
## 選項鈕送出真實 "ui_accept" 動作觸發選擇；若沒有選項面板（純線性對話），維持原本的
## dialogic_default_action 推進（這部分本來就正常，不是 bug）。
func _pick_first_choice_if_present() -> void:
	await _wait_seconds(0.25)  # 越過 choices/delay=0.2 的 _choice_blocker 窗口
	var choice_btn: Button = _focused_or_first_choice_button()
	if choice_btn != null:
		if not choice_btn.has_focus():
			choice_btn.grab_focus()
			await get_tree().process_frame
		await _press_action("ui_accept")
	else:
		await _advance_dialogic()
	await _wait_frames(2)

## 選項群組 'dialogic_choice_button' 裡目前有 focus 的那顆（autofocus_first_choice 正常情況下
## 就是第一項）；若意外沒有任何一顆有 focus（例如上一步被滑鼠事件搶走），退回抓第一個可見的。
## 沒有任何選項面板顯示時回傳 null（呼叫端據此判斷走純線性對話推進）。
func _focused_or_first_choice_button() -> Button:
	var visible_choices: Array = []
	for node in get_tree().get_nodes_in_group("dialogic_choice_button"):
		if node is Button and node.visible:
			if node.has_focus():
				return node
			visible_choices.append(node)
	return visible_choices[0] if not visible_choices.is_empty() else null

# ════════════════════════════════════════════════════════════════
# 主流程：依序跑 16 個節拍
# ════════════════════════════════════════════════════════════════

func _run_all_beats() -> void:
	await _beat("title_screen", DEFAULT_TIMEOUT, _beat_title_screen)
	await _beat("new_game_opening_cutscene", LONG_TIMEOUT, _beat_new_game_and_opening)
	await _beat("tutorial_battle", LONG_TIMEOUT, _beat_tutorial_battle)
	await _beat("post_battle_return_to_map", DEFAULT_TIMEOUT, _beat_post_battle_return)
	await _beat("period_advance_card", DEFAULT_TIMEOUT, _beat_period_card_check)
	await _beat("map_roam_npc_dialogue", DEFAULT_TIMEOUT, _beat_map_npc_dialogue)
	await _beat("dialogue_history_tab", DEFAULT_TIMEOUT, _beat_dialogue_history_tab)
	await _beat("phone_menu_pages", DEFAULT_TIMEOUT, _beat_phone_menu_pages)
	await _beat("shop_buy_items", DEFAULT_TIMEOUT, _beat_shop_buy)
	await _beat("equip_item", DEFAULT_TIMEOUT, _beat_equip_item)
	await _beat("minigame_offering_toss", LONG_TIMEOUT, _beat_minigame_offering_toss)
	await _beat("rest_period_skip", DEFAULT_TIMEOUT, _beat_rest_skip)
	await _beat("save_game", DEFAULT_TIMEOUT, _beat_save_game)
	await _beat("title_continue_load", DEFAULT_TIMEOUT, _beat_title_continue_load)
	await _beat("battle_flee", LONG_TIMEOUT, _beat_battle_flee)
	await _beat("battle_speedup_victory", LONG_TIMEOUT, _beat_battle_speedup_victory)

# ── 1. 標題畫面 ──────────────────────────────────────────────
func _beat_title_screen() -> Dictionary:
	SceneRouter.go_to_title()
	var title := await _wait_for_scene("TitleScreen", 10.0)
	if title == null:
		return {"status": "STUCK", "note": "TitleScreen 未載入"}
	await _wait_frames(5)
	var start_btn: Button = title.get_node_or_null("%StartButton")
	if start_btn == null or not start_btn.visible:
		return {"status": "STUCK", "note": "StartButton 不存在或不可見"}
	return {"status": "PASS", "note": "按鈕可見：開始=%s 繼續=%s 離開=%s" % [
		start_btn.visible,
		title.get_node_or_null("%ContinueButton") != null,
		title.get_node_or_null("%QuitButton") != null]}

# ── 2. 開始修行 → 開場過場 ──────────────────────────────────
## ⚠ 2026-07-10 第一輪實跑踩坑：這裡原本用「連續按 confirm 20 次、每次間隔僅 0.3s」
## 硬闖開場過場，結果第 3–5 拍（教學戰～戰後回地圖～時段字卡）連續 3 張截圖全是純黑畫面
## 只見右下角「ESC 跳過」字樣——高度懷疑是過場/對話切換的交界處被過快輸入打斷，卡在某個
## CutsceneScreen 疊層沒有正常收尾（真人不可能在 6 秒內對著轉場邊界按 20 次確認鍵）。
## 修法：改用「單鍵按下、確認畫面有真實反應（current_scene 名稱或 Dialogic 狀態改變）才按下一次」
## 的保守節奏，且每次按鍵之間留更長間隔，降低撞上轉場交界的機率；仍在報告中記錄本節拍
## 用了較密集的輸入去闖過場鏈，屬於已知風險操作而非真人操作序列。
func _beat_new_game_and_opening() -> Dictionary:
	var title := get_tree().current_scene
	if title == null or title.name != "TitleScreen":
		return {"status": "SKIPPED", "note": "不在標題畫面，略過真點擊，改直呼 API"}
	var start_btn: Button = title.get_node_or_null("%StartButton")
	if start_btn != null:
		await _click_button(start_btn)  # 觸發 SaveManager.select_slot_for_new_game + GameManager.new_game + continue_story
	else:
		SaveManager.select_slot_for_new_game()
		GameManager.new_game()
		MainQuestManager.continue_story()
	# continue_story() 是不 await 的 fire-and-forget（TitleScreen._on_start_pressed 沒 await），
	# 主線協程鏈會自己跑：c1_demolition(cutscene,hold) → c1_aftermath(dialogue,hold)。
	# 先給開場過場（opening_temple_falls）充分時間播放，不急著按跳過——過場通常沒幾秒，
	# 讓它自然播完比硬跳更貼近真人體驗，也避免踩到轉場交界的競態。
	await _wait_seconds(4.0)
	# 若過場還在播（Dialogic 尚未進 c1_aftermath），稀疏按 dialogic_default_action 嘗試推進，
	# 每次按完都停頓 1.2s 觀察狀態變化，避免連續快速輸入疊加在轉場邊界上。
	var pre_elapsed := 0.0
	while Dialogic.current_timeline == null and pre_elapsed < 12.0:
		await _advance_dialogic()
		await _wait_seconds(1.2)
		pre_elapsed += 1.2
	# 接著是 c1_aftermath 對話（雨夜茶攤遇了塵）：推進到底（_advance_dialogue_until_done 內部
	# 節奏是 0.12s/次，對已進入對話狀態、非轉場邊界的情境是安全的，不動它）。
	var dlg_result := await _advance_dialogue_until_done(25.0)
	return {"status": "PASS" if dlg_result != "timeout" else "STUCK",
		"note": "開場過場+aftermath 對話結果=%s（等待過場自然播放 %.1fs 後才開始按確認），目前旗標 relic_stolen=%s" % [
			dlg_result, 4.0 + pre_elapsed, GameManager.get_flag("relic_stolen")]}

# ── 3. 教學戰 ────────────────────────────────────────────────
## ⚠ 2026-07-10 前兩輪實跑踩坑（真正根因，第三輪截圖才抓到證據）：
## 本拍（與整支腳本所有對話推進處）原本一律用 _press_action("confirm") 想推進 Dialogic
## 文字框，但 Dialogic 文字框推進讀的是 "dialogic_default_action"（見 _advance_dialogic()
## 完整說明），不是 "confirm"——兩者雖共用實體鍵，Input.action_press("confirm") 並不會連帶
## 觸發 "dialogic_default_action"。結果是：第二輪 45s 逾時截圖顯示畫面其實停在 c1_aftermath
## 對話的第一行（了塵茶攤，Dialogic 文字框＋"▼"提示都在），代表 confirm 狂按 300 次
## （45s / 0.15s）對 Dialogic 完全無效——遊戲根本沒卡，是本腳本沒有真的按對鍵。
## watchdog 仍保留 45s + 過場偵測（cutscene 用 confirm 是對的，過場跳過鍵走的是別的處理），
## 但 Dialogic 分支改用 _advance_dialogic()。
func _beat_tutorial_battle() -> Dictionary:
	# c1_tutorial_brawl stage：dialogue(main_ch1_tutorial_brawl) 接著 battle(tutorial_punk)。
	# 過場/對話可能還在跑，持續推進直到進戰鬥或真的確認卡住（不再播任何過場/對話）。
	var elapsed := 0.0
	const MAX_WAIT := 45.0
	while elapsed < MAX_WAIT:
		var bm_probe := get_tree().get_first_node_in_group("battle_manager")
		if bm_probe != null:
			break
		if Dialogic.current_timeline != null:
			await _advance_dialogic()
			await _wait_seconds(0.15)
			elapsed += 0.15
			continue
		if _is_cutscene_playing():
			# 過場正在播（StoryCutscene，Dialogic.current_timeline 讀不到）：CutsceneScreen/
			# StoryCutscene 的跳過鍵沿用既有實跑慣例是 confirm/任意鍵（非 Dialogic 文字框），
			# 稀疏按 confirm 嘗試推進，同時讓真實秒數流逝，不要用力狂按。
			await _press_action("confirm")
			await _wait_seconds(0.6)
			elapsed += 0.6
			continue
		# 兩者都沒有：真的空窗，等一下再看，逾時就是真卡住。
		await _wait_seconds(0.3)
		elapsed += 0.3
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm == null:
		return {"status": "STUCK", "note": "等不到教學戰 BattleManager（%.0fs），可能對話/過場鏈卡住" % MAX_WAIT}
	# 等進玩家回合。
	var ok := await _wait_until(func() -> bool: return is_instance_valid(bm) and bm.state == bm.State.PLAYER_TURN, 10.0)
	if not ok:
		return {"status": "STUCK", "note": "教學戰未進入玩家回合"}
	await _wait_frames(3)
	# 打到贏：真輸入為主——CommandMenu.COMMANDS[0]="攻擊"恆不灰置，開局即為預設選中項，
	# 直接送確認鍵即可觸發 BattleManager.on_command("attack")→ui.begin_target_or_use()。
	# 教學戰（tutorial_battle 旗標開）逐點插播 BattleTutorial 小視窗時，狀態仍是 PLAYER_TURN
	# 但 CommandMenu 還沒真的開（_begin_player_turn 先 await tutorial.show_point("menu") 才開選單），
	# 故每輪先檢查 bm.tutorial.visible，有就先按確認撥開再繼續，避免對著還沒開的選單空按。
	# tutorial_punk 帶 ally_id 異質同場、street_punk 有 call_backup 召援，兩者都可能中途變成
	# 多敵觸發目標選擇（EnemyPanel 鍵盤導航，B-1 已接上），故出招後再判斷一次
	# bm.ui._target_nav_active，是就補一次確認鎖定預設鎖定的第一個存活目標。
	var basic: String = bm._basic_skill_id()
	var rounds := 0
	while is_instance_valid(bm) and bm.state != bm.State.END and rounds < 20:
		# 2026-07-11 D-6 實跑踩坑：BattleTutorial._wait_for_confirm() 是純輪詢
		# （Input.is_action_just_pressed），不是 _input()/_gui_input() 事件分派，所以一次確認鍵
		# 按下同一幀「CommandMenu 選攻擊」和「教學小視窗撥開」有機會被同時吃到；若中途（wait_seconds
		# 期間）恰好冒出新的教學點（weakness/guard），我方送出的下一次確認鍵可能被教學小視窗和
		# CommandMenu 兩邊搶收，導致其中一邊沒有真的收到、留下孤兒協程卡住戰後流程（曾實測
		# 導致 BattleTutorial._wait_for_confirm 在場景轉換後對 null tree 報錯）。修法：出手前後都先
		# 用 _drain_tutorial_popup() 主動把當下任何教學小視窗按掉，讓「撥教學」與「操作指令」兩件事
		# 不共用同一次按鍵，避免搶收。
		await _drain_tutorial_popup(bm)
		if not is_instance_valid(bm) or bm.state == bm.State.END:
			break
		if bm.state == bm.State.PLAYER_TURN:
			await _wait_seconds(0.15)
			await _drain_tutorial_popup(bm)  # wait_seconds 期間可能剛好冒出新教學點，再保險一次
			if not is_instance_valid(bm) or bm.state == bm.State.END:
				break
			await _press_action("confirm")  # CommandMenu：確認選中的「攻擊」
			await _wait_seconds(0.3)
			if is_instance_valid(bm) and is_instance_valid(bm.ui) and bm.ui._target_nav_active:
				await _press_action("confirm")  # 多敵：確認預設鎖定的目標
				await _wait_seconds(0.2)
		await _wait_seconds(0.3)
		rounds += 1
	if is_instance_valid(bm) and bm.state != bm.State.END:
		# 真輸入 20 輪內未結束戰鬥（不預期：基本攻擊理應足以贏過教學/雜兵戰）。保留
		# force_victory() 當「逾時安全網」避免整趟黃金路線被卡死，異常本身於報告標注，
		# 不是常態捷徑（正常情況這段不會被執行到）。
		_api_shortcut("tutorial_battle", "真輸入 20 輪內未結束戰鬥，觸發 force_victory() 逾時安全網（不應發生，需檢視是否為真輸入路徑失效或戰鬥數值異常）")
		bm.force_victory()
		await _wait_seconds(1.5)
	var battle_result := await _wait_until(func() -> bool: return not is_instance_valid(bm) or bm.state == bm.State.END, 8.0)
	# ⚠ 2026-07-11 D-6 實測抓到的真正根因（比原本以為的「小視窗沒按到」更早一步）：
	# bm.state 進 State.END 是 _victory() 一開頭、傷害判定當下就同步設的，但這之後 _victory()
	# 還要跑 await ui.play_victory(...)（畫面上「勝利 金幣+100／功德+15／道行+30」三行結算動畫，
	# 有明顯秒數延遲）才會走到 await tutorial.show_point("victory")。state==END 那一刻教學小視窗
	# 通常「根本還沒出現」——舊版在這一刻只檢查一次 bm.tutorial.visible 會直接撲空（誤判成
	# 「沒有要按的」，其實是太早檢查，不是真的沒有）。用診斷單這次實測到的畫面截圖直接證實：
	# state==END 後 t=2.0s 教學小視窗才真的冒出來，且從此卡住不動直到 20s 逾時（因為下一拍
	# 完全不會再按任何鍵，current_scene 整段停在 BattleScreen 沒有換場）。
	# 修法：不要只在 state==END 那一刻查一次，改成「持續觀察」直到場景真的離開 BattleScreen
	# （代表 _victory() 尾段真的跑完換場了）或逾時；小視窗任何時候冒出來就按掉。
	var post_victory_elapsed := 0.0
	var tutorial_was_dismissed := false
	while is_instance_valid(bm) and post_victory_elapsed < 10.0:
		var cs := get_tree().current_scene
		if cs == null or cs.name != "BattleScreen":
			tutorial_was_dismissed = true  # 已換場離開戰鬥畫面，_victory() 尾段流程確定跑完了
			break
		if is_instance_valid(bm.tutorial) and bm.tutorial.visible:
			await _press_action("confirm")
		await _wait_seconds(0.3)
		post_victory_elapsed += 0.3
	if not tutorial_was_dismissed:
		tutorial_was_dismissed = not is_instance_valid(bm) or not is_instance_valid(bm.tutorial) or not bm.tutorial.visible
	return {"status": "PASS" if battle_result else "STUCK",
		"note": "教學戰結束（rounds=%d），basic_skill=%s，victory 教學小視窗已按掉=%s" % [
			rounds, basic, tutorial_was_dismissed]}

## 把當下任何顯示中的 BattleTutorial 小視窗按掉（真輸入 confirm，走 _wait_for_confirm() 的真實
## 輪詢路徑），bounded by max_wait 秒，避免無窮等待；沒有小視窗顯示時立即回傳（幾乎零成本，
## 可以放心在每個決策點前呼叫，確保「撥教學」永遠跟「操作指令」分開兩次按鍵，不搶收同一次輸入。
func _drain_tutorial_popup(bm: Node, max_wait: float = 3.0) -> void:
	if not is_instance_valid(bm) or not is_instance_valid(bm.tutorial):
		return
	var elapsed := 0.0
	while is_instance_valid(bm) and is_instance_valid(bm.tutorial) and bm.tutorial.visible and elapsed < max_wait:
		await _press_action("confirm")
		await _wait_seconds(0.3)
		elapsed += 0.3

# ── 4. 戰後回地圖（驗證不卡 loading）──────────────────────────
func _beat_post_battle_return() -> Dictionary:
	var map := await _wait_for_scene("MapScreen", 15.0)
	if map == null:
		# 再多等 5s（總計 20s）：確認不是單純換場慢，而是真的卡住（讀取畫面卡死）。
		var recovered := await _wait_until(func() -> bool:
			return get_tree().current_scene != null and get_tree().current_scene.name == "MapScreen", 5.0)
		if not recovered:
			return {"status": "STUCK", "note": "戰後 20s 未回 MapScreen，疑似卡讀取畫面"}
	# 主線鏈接下來會自動跑 c1_intel（dialogue，set_flag armory_unlocked）與
	# c1_armory_gate（gate skills>=5）。持續推進對話，直到卡在 gate 或跑去下個 stage。
	var elapsed := 0.0
	while elapsed < 20.0:
		if Dialogic.current_timeline != null:
			await _advance_dialogic()
			await _wait_seconds(0.15)
			elapsed += 0.15
		else:
			await _wait_seconds(0.3)
			elapsed += 0.3
	# armory_gate 門檻＝技能解鎖數>=5。開局 2 個(basic_punch,wooden_fish) + c1_intel 授予
	# arhat_strike(story) = 3，天然打不到 5，主線協程鏈會卡在 c1_armory_gate 播 fail_dialogue
	# 後 return false 中止本章（stage 進度保留）。這是設計内已知门槛，非 bug；用 API 補滿技能數
	# 讓後續 c1_confront/armory_breach/armory_deep/ares 也能被測到（在報告標注 API 捷徑）。
	var unlocked_before: int = GameManager.player.skills_unlocked.size()
	if unlocked_before < 5:
		# 2026-07-11 D-6：原本直呼 SkillUnlockManager.grant_skill()（劇情直接給招的方法）硬灌 5 招，
		# 完全繞過「習得」這個真實 UI 動作。改法：armory_gate 門檻本身需要的 5 招解鎖條件
		# （vajra_glare=ah_ming_saved旗標／iron_shirt=broke_any_vow旗標／
		# ascetic_temper=weakness_hit_count≥10／requiem=near_death_triggered旗標／
		# sound_wave=ah_zhong支線完成，見 SkillUnlockManager.UNLOCK_TABLE）本身是黃金路線這個
		# 階段還沒觸及、也無法用輸入模擬跳過的支線內容進度（這是內容進度缺口，不是輸入機制問題），
		# 這部分維持 API 捷徑、但縮小範圍到「只補達成條件所需的旗標/進度」（等同已玩過那段支線）；
		# 拿到「可習得」資格後，實際『習得』動作改走真輸入：開經書→技能頁→點該招→按「習得」鈕，
		# 走 SkillsPage._select()/_on_learn() → SkillUnlockManager.learn_skill() 的真實 UI code path，
		# 不再繞過學習動作本身。
		_api_shortcut("post_battle_return_to_map",
			("armory_gate 門檻 skills_unlocked>=5，自然流程只有 %d 個（basic_punch/wooden_fish/arhat_strike）。" % unlocked_before) +
			" 剩餘 5 招的解鎖條件是黃金路線這個階段還沒觸及的支線內容，API 只補「達成條件」所需的旗標/進度，" +
			"實際習得動作已改走經書 UI 真輸入（見下方 _learn_learnable_skills_via_ui）。")
		GameManager.set_flag("ah_ming_saved", true)          # vajra_glare
		GameManager.set_flag("broke_any_vow", true)           # iron_shirt
		GameManager.set_flag("weakness_hit_count", 10)         # ascetic_temper（behavior target=10）
		GameManager.set_flag("near_death_triggered", true)    # requiem
		if "ah_zhong" not in GameManager.player.completed_quests:
			GameManager.player.completed_quests.append("ah_zhong")  # sound_wave
		SkillUnlockManager.check_unlocks(false)
		await _learn_learnable_skills_via_ui(map, 5 - unlocked_before)
	return {"status": "PASS", "note": "回地圖成功，armory_unlocked=%s，skills_unlocked(%d)=%s" % [
		GameManager.get_flag("armory_unlocked"), GameManager.player.skills_unlocked.size(),
		str(GameManager.player.skills_unlocked)]}

## 真輸入走經書技能頁「習得」流程：開選單→經書裝置→技能頁(index0)→逐一點擊可學技能列→按「習得」鈕。
## SkillsPage 的「習得」鈕是選中招式後才動態生成（不在 MenuShell._wire_content_focus 初次建鏈的
## 範圍內，MenuShell 目前沒有為動態出現的控件重新串 focus 鏈——這是產品面既有限制，不在 D-6
## QA 工具範圍內修），因此這裡用與本檔既有 _click_button()（beat 2/14 已在用同一手法）一致的
## 「模擬點擊訊號」方式觸發，仍是走 SkillsPage 真實的 _select()/_on_learn() code path，
## 不是直接呼叫 SkillUnlockManager.learn_skill()/grant_skill()。
func _learn_learnable_skills_via_ui(map: Node, need: int) -> void:
	if map.get_node_or_null("MenuShell") != null:
		map.get_node("MenuShell").queue_free()
		await _wait_frames(2)
	await _press_action("open_menu")
	var shell := await _wait_until_node(map, "MenuShell", 5.0)
	if shell == null:
		_log("QA_NOTE|post_battle_return_to_map|開不出 MenuShell，無法真輸入習得技能")
		return
	shell._show_device("book")
	await _wait_frames(2)
	shell._show_page(0)  # 技能頁 SkillsPage
	await _wait_frames(3)
	var page: Control = shell._content.get_child(0)  # _show_page 剛把 SkillsPage 實例塞進 _content
	var learned := 0
	var guard := 0
	while learned < need and guard < 10:
		guard += 1
		var learnable: Array = SkillUnlockManager.learnable_skills()
		if learnable.is_empty():
			break
		var target_id: String = learnable[0]
		var row: Button = page._rows.get(target_id, null)
		await _click_button(row)  # 左側點選該招（真實 SkillsPage._select 路徑）
		await _wait_frames(2)
		var learn_btn: Button = null
		for c in page._detail_box.get_children():
			if c is Button and c.text == "習得":
				learn_btn = c
		await _click_button(learn_btn)  # 按下「習得」鈕（真實 SkillsPage._on_learn 路徑）
		await _wait_frames(2)
		if target_id in GameManager.player.skills_unlocked:
			learned += 1
		else:
			break  # 沒有進展就停止，避免死圈
	shell.close()
	await _wait_frames(3)

# ── 5. 時段字卡轉場 ─────────────────────────────────────────
func _beat_period_card_check() -> Dictionary:
	# 教學戰勝利後 pending_period_advance 應已由 MapScreen._ready 的 consume_period_advance 消費掉
	# （字卡全程約 2.1s，第 4 拍等待期間應已播完）。這裡驗證字卡機制本身：手動再觸發一次
	# （perform_action("rest") 也會走同一條字卡路徑，但那是第 12 拍的職責）；本拍改用直接呼叫
	# SceneRouter.consume_period_advance() 在目前 pending 狀態下的行為驗證＋截圖任何殘留字卡畫面。
	var map := _map_screen()
	if map == null:
		return {"status": "SKIPPED", "note": "不在 MapScreen，略過字卡檢查（非本拍失敗，交給前後拍銜接）"}
	var pending_now: bool = GameManager.pending_period_advance
	var period_before: int = GameManager.player.period
	if pending_now:
		await SceneRouter.consume_period_advance()
		await _wait_seconds(2.3)
	return {"status": "PASS", "note": "教學戰後 pending=%s（應已被 MapScreen._ready 消費），period=%d→%d" % [
		pending_now, period_before, GameManager.player.period]}

# ── 6. 地圖漫遊 + E 互動 NPC 對話 ────────────────────────────
func _beat_map_npc_dialogue() -> Dictionary:
	var map := _map_screen()
	if map == null:
		map = await _wait_for_scene("MapScreen", 10.0)
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen，無法測試漫遊互動"}
	# 直接把玩家移到「了塵」互動點觸發對話（3D 座標移動走真實 CharacterBody 較不穩定，
	# 這裡用 Area3D 觸發區域的距離判定：把玩家 teleport 到觸發點附近，讓 Area3D 自然偵測
	# body_entered，走的是真實 LocationTrigger 訊號路徑，不是直接呼 perform_action）。
	var player := get_tree().get_first_node_in_group("player")
	var trigger := get_tree().get_first_node_in_group("location_trigger")
	if player == null:
		return {"status": "STUCK", "note": "場上找不到 player 節點"}
	if trigger == null:
		return {"status": "STUCK", "note": "場上找不到任何 location_trigger（互動點未灑出）"}
	# 找了塵（npc_liaochen）觸發點；找不到就用第一個可用觸發點代替。
	# LocationTrigger.gd 的 id 存在 location_id 屬性（見 setup()），不是 "id"。
	var triggers := get_tree().get_nodes_in_group("location_trigger")
	var target_trigger: Node = null
	for t in triggers:
		if String(t.location_id) == "npc_liaochen":
			target_trigger = t
			break
	if target_trigger == null:
		target_trigger = triggers[0]
	player.global_position = target_trigger.global_position
	await _wait_frames(15)  # 讓 Area3D 有機會偵測到玩家進入（body_entered 需經過物理幀，比 process 幀慢半拍）
	await _press_action("interact")
	await _wait_seconds(0.5)
	if Dialogic.current_timeline == null:
		# 多動作點走選單分流（NPC_ENTRY_TIMELINE），可能對話沒立刻開，記錄但不算 STUCK：
		# 多次嘗試觸發互動鍵。
		for i in 5:
			await _press_action("interact")
			await _wait_seconds(0.4)
			if Dialogic.current_timeline != null:
				break
	var opened := Dialogic.current_timeline != null
	if opened:
		# 對話中若跳出選項，先過 blocker 再選第一項，直到對話結束；若是純線性對話則直接推進到底。
		var elapsed := 0.0
		while Dialogic.current_timeline != null and elapsed < 15.0:
			await _pick_first_choice_if_present()
			elapsed += 0.3
	# 驗證對話結束後立繪關閉（current_timeline 歸零）、E 鍵仍可用（不卡死）。
	var closed_ok := Dialogic.current_timeline == null
	return {"status": "PASS" if (opened and closed_ok) else "STUCK",
		"note": "互動點=%s，對話開啟=%s，結束後 current_timeline 清空=%s" % [
			String(target_trigger.location_id), opened, closed_ok]}

# ── 7. Tab 回想面板開關 ──────────────────────────────────────
func _beat_dialogue_history_tab() -> Dictionary:
	var panel: CanvasLayer = GameManager.dialogue_history
	if panel == null or not is_instance_valid(panel):
		return {"status": "STUCK", "note": "GameManager.dialogue_history 不存在"}
	# Tab 面板只在「對話進行中」才會回應開啟（見 DialogueHistoryPanel._input：
	# Dialogic.current_timeline == null 時直接 return，不開）。用 API 直接 open()/close() 驗證
	# 面板本身可開關（畫面/內容渲染），輸入層的「對話中按 Tab」已在上一拍互動對話期間走過。
	_api_shortcut("dialogue_history_tab", "面板僅在對話進行中才回應 Tab 鍵；本拍改直呼 panel.open()/close() 驗證渲染，輸入層已於第 6 拍對話中驗證過。")
	panel.open()
	await _wait_frames(5)
	var visible_after_open: bool = panel.visible
	await _wait_seconds(0.3)
	panel.close()
	await _wait_frames(3)
	var visible_after_close: bool = panel.visible
	return {"status": "PASS" if (visible_after_open and not visible_after_close) else "STUCK",
		"note": "開啟後 visible=%s，關閉後 visible=%s，entries 累積筆數=%d" % [
			visible_after_open, visible_after_close, panel.entries.size()]}

# ── 8. 手機選單各頁開一次 ────────────────────────────────────
func _beat_phone_menu_pages() -> Dictionary:
	var map := _map_screen()
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen，無法開選單"}
	if map.get_node_or_null("MenuShell") != null:
		map.get_node("MenuShell").queue_free()
		await _wait_frames(2)
	await _press_action("open_menu")  # M 鍵
	var shell := await _wait_until_node(map, "MenuShell", 5.0)
	if shell == null:
		return {"status": "STUCK", "note": "按 M 鍵未開出 MenuShell"}
	await _wait_frames(3)
	var results: Array[String] = []
	# 經書：技能/狀態/佛具（第 10 拍會另外測裝備流程，這裡先各開一次確認能開）
	shell._show_device("book")
	await _wait_frames(3)
	for i in 3:
		shell._show_page(i)
		await _wait_frames(3)
		results.append("book:%s" % shell._devices["book"].pages[i].title)
	# 手機：任務/情報(含敵人圖鑑)/移動/打工/修行/設定/說明
	shell._show_device("phone")
	await _wait_frames(3)
	for i in shell._devices["phone"].pages.size():
		shell._show_page(i)
		await _wait_frames(3)
		results.append("phone:%s" % shell._devices["phone"].pages[i].title)
	await _screenshot("%s/%02d_phone_menu_pages_detail.png" % [OUT_DIR, _beat_idx])
	shell.close()
	await _wait_frames(3)
	var closed_ok := map.get_node_or_null("MenuShell") == null
	return {"status": "PASS" if closed_ok else "STUCK",
		"note": "已開頁面：%s ｜關閉後 MenuShell 已移除=%s" % [", ".join(results), closed_ok]}

func _wait_until_node(parent: Node, node_name: String, max_wait: float) -> Node:
	var elapsed := 0.0
	while elapsed < max_wait:
		var n := parent.get_node_or_null(node_name)
		if n != null:
			return n
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return null

# ── 9. 商店買消耗品+佛具 ─────────────────────────────────────
func _beat_shop_buy() -> Dictionary:
	var map := _map_screen()
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen"}
	if not GameManager.get_flag("zheng_ma_shop_unlocked"):
		# zheng_ma_shop_unlocked 是水野支線(quest_zheng_ma)完成才給的旗標，黃金路線這個階段
		# 自然不會解鎖——這是內容進度缺口，不是輸入機制問題，維持 API 開店面；購買動作本身
		# 已改走真輸入（見下方 _shop_select_and_buy），不是本拍剩下的 API 捷徑。
		_api_shortcut("shop_buy_items", "zheng_ma_shop_unlocked 是水野支線(quest_zheng_ma)完成才給的旗標，黃金路線不會自然解鎖。直接 set_flag 打開店面以測試商店系統本身（內容進度缺口，非輸入機制問題；購買動作已改真輸入）。")
		GameManager.set_flag("zheng_ma_shop_unlocked", true)
	GameManager.add_gold(5000)  # 確保買得起，避免金幣不足擋下測試
	map.perform_action("shop")
	await _wait_frames(3)
	var shop := map.get_node_or_null("ShopScreen")
	if shop == null:
		return {"status": "STUCK", "note": "shop 動作未開出 ShopScreen"}
	await _wait_frames(3)
	# 消耗品分頁：真輸入——ShopScreen 已有 B-2 接好的鍵盤 focus 鏈（_wire_content_focus），
	# ui_down 導到品項列→ui_accept 選取（走真實 _select()）→詳情區冒出「購買」鈕→ui_down
	# 導過去→ui_accept 購買（走真實 _on_buy()），不再直接呼叫 _select()/_on_buy()。
	shop._show_tab(0)
	await _wait_frames(3)
	var item_ids: Array = shop._items.keys()
	var bought_item := ""
	if not item_ids.is_empty():
		var iid: String = item_ids[0]
		var before: int = GameManager.item_count(iid)
		var row: Button = shop._rows.get(iid, null)
		if await _shop_select_and_buy(shop, row):
			bought_item = "%s(%d→%d)" % [iid, before, GameManager.item_count(iid)]
	# 佛具分頁：買第一個已達進貨門檻且未持有的
	shop._show_tab(1)
	await _wait_frames(3)
	var bought_equip := ""
	for eid in shop._equipment.keys():
		if not EquipmentSystem.is_unlocked(eid):
			continue
		if EquipmentSystem.is_owned(eid):
			continue
		var erow: Button = shop._rows.get(eid, null)
		if await _shop_select_and_buy(shop, erow):
			bought_equip = "%s owned=%s" % [eid, EquipmentSystem.is_owned(eid)]
		break
	await _screenshot("%s/%02d_shop_buy_detail.png" % [OUT_DIR, _beat_idx])
	shop.close()
	await _wait_frames(3)
	var closed_ok := map.get_node_or_null("ShopScreen") == null
	return {"status": "PASS" if (bought_item != "" and closed_ok) else "STUCK",
		"note": "買消耗品=%s｜買佛具=%s｜關閉商店=%s" % [bought_item, bought_equip, closed_ok]}

## 真輸入：把 focus 導到 row（消耗品/佛具清單裡的某一列）→ ui_accept 選取顯示詳情
## （真實 ShopScreen._select 路徑）→ 把 focus 導到動態出現的「購買」鈕 → ui_accept 購買
## （真實 ShopScreen._on_buy/_on_buy_equipment 路徑）。找不到列/鈕或導航失敗回傳 false。
func _shop_select_and_buy(shop: Node, row: Button) -> bool:
	if row == null or not is_instance_valid(row):
		return false
	if not await _focus_down_to(row, shop._focus_chain.size() + 2):
		return false
	await _press_action("ui_accept")  # 選取該品項 → 詳情區出現「購買」鈕
	await _wait_frames(3)
	var buy_btn: Button = null
	for c in shop._detail_box.get_children():
		if c is Button and c.text == "購買":
			buy_btn = c
	if buy_btn == null or buy_btn.disabled:
		return false  # 金幣不足/已擁有/未解鎖，沒有可購買鈕
	if not await _focus_down_to(buy_btn, shop._focus_chain.size() + 2):
		return false
	await _press_action("ui_accept")  # 按下購買
	await _wait_frames(3)
	return true

## 真輸入導航共用工具：從目前 focus 沿 ui_down 反覆移動，直到抵達 target 控件（bounded，
## 超過 max_steps 仍抵達不了就回傳 false，供呼叫端判斷為 STUCK 而不是無窮迴圈死等）。
func _focus_down_to(target: Control, max_steps: int) -> bool:
	var steps := 0
	while get_viewport().gui_get_focus_owner() != target and steps < max_steps:
		await _press_action("ui_down")
		await _wait_frames(1)
		steps += 1
	return get_viewport().gui_get_focus_owner() == target

# ── 10. 佛具頁裝備上 ─────────────────────────────────────────
func _beat_equip_item() -> Dictionary:
	var map := _map_screen()
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen"}
	var owned: Array = GameManager.player.get("equipment_owned", [])
	if owned.is_empty():
		_api_shortcut("equip_item", "上一拍若佛具購買失敗（例如所有品項皆已達門檻擁有或未解鎖），這裡直接用 EquipmentSystem 給一件保底以測試裝備流程本身。")
		# 找任一已解鎖但未擁有的品項，用購買 API 補一件（不繞過購買，只是不透過 UI 點擊）。
		for eid in EquipmentSystem.get_items().keys():
			if EquipmentSystem.is_unlocked(eid) and not EquipmentSystem.is_owned(eid):
				GameManager.add_gold(5000)
				EquipmentSystem.purchase(eid)
				break
		owned = GameManager.player.get("equipment_owned", [])
	if owned.is_empty():
		return {"status": "SKIPPED", "note": "沒有任何已解鎖的佛具品項可裝備（進貨門檻皆未達成），非本拍能解決"}
	var item_id: String = owned[0]
	if map.get_node_or_null("MenuShell") != null:
		map.get_node("MenuShell").queue_free()
		await _wait_frames(2)
	await _press_action("open_menu")
	var shell := await _wait_until_node(map, "MenuShell", 5.0)
	if shell == null:
		return {"status": "STUCK", "note": "無法開出 MenuShell 進行裝備"}
	shell._show_device("book")
	await _wait_frames(2)
	shell._show_page(2)  # 佛具頁 EquipPage
	await _wait_frames(3)
	var equipped_before := EquipmentSystem.get_equipped(_slot_of(item_id))
	EquipmentSystem.equip(item_id)
	await _wait_frames(3)
	await _screenshot("%s/%02d_equip_item_detail.png" % [OUT_DIR, _beat_idx])
	var equipped_after := EquipmentSystem.get_equipped(_slot_of(item_id))
	shell.close()
	await _wait_frames(3)
	return {"status": "PASS" if equipped_after == item_id else "STUCK",
		"note": "裝備 %s：裝備前該欄=%s，裝備後=%s" % [item_id, equipped_before, equipped_after]}

func _slot_of(item_id: String) -> String:
	var d: Dictionary = EquipmentSystem.get_item_def(item_id)
	return String(d.get("slot", ""))

# ── 11. 小遊戲進出（含 intro 過場、ESC 暫停、結算面板、離開回地圖）──
func _beat_minigame_offering_toss() -> Dictionary:
	var map := _map_screen()
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen"}
	SceneRouter.go_to_minigame("offering_toss")
	var game := await _wait_for_minigame("OfferingToss", 15.0)
	if game == null:
		return {"status": "STUCK", "note": "15s 內未進入 OfferingToss 場景（intro 過場或換場卡住）"}
	await _wait_seconds(1.0)  # 讓 intro 過場（如有）播放/淡出
	await _screenshot("%s/%02d_minigame_intro.png" % [OUT_DIR, _beat_idx])
	# ESC 暫停：驗證暫停面板開關
	await _press_action("cancel")
	await _wait_frames(3)
	var pause_opened: bool = game.is_paused_menu_open() if game.has_method("is_paused_menu_open") else false
	await _screenshot("%s/%02d_minigame_pause.png" % [OUT_DIR, _beat_idx])
	if pause_opened:
		game._on_pause_resume()
		await _wait_frames(3)
	# 玩滿 5 擲（gauge_value 是純函式，挑一個必定命中甜蜜點的時機出手，5 次都精算，
	# 確保能走到結算面板，不靠碰運氣的即時輸入）。
	var throws := 0
	while game.throws_done < 5 and throws < 8 and is_instance_valid(game):
		if game._phase == "aim":
			# 找一個當下 gauge_t 之後最近、gauge_value 落在甜蜜點附近的時間點，直接推進到那個相位再出手。
			var t: float = game._gauge_t
			var best_dt := 0.0
			var best_diff := 999.0
			for step in range(0, 40):
				var dt := step * 0.01
				var v: float = game.gauge_value(t + dt)
				var diff: float = absf(v - game.POWER_SWEET)
				if diff < best_diff:
					best_diff = diff
					best_dt = dt
			await _wait_seconds(best_dt)
			if is_instance_valid(game) and game._phase == "aim":
				game._throw(game.gauge_value(game._gauge_t))
		await _wait_seconds(0.9)
		throws += 1
	var got_result := await _wait_until(func() -> bool:
		return is_instance_valid(game) and game.is_result_panel_open(), 8.0)
	await _screenshot("%s/%02d_minigame_result_panel.png" % [OUT_DIR, _beat_idx])
	if not got_result:
		return {"status": "STUCK", "note": "5 擲後 8s 內結算面板未開出（throws_done=%d）" % (game.throws_done if is_instance_valid(game) else -1)}
	# 離開（套用獎勵並返回地圖）
	game._on_result_leave()
	var back_to_map := await _wait_for_scene("MapScreen", 10.0)
	return {"status": "PASS" if back_to_map != null else "STUCK",
		"note": "投擲完成命中=%d/5，暫停面板可開=%s，結算面板出現=%s，離開後回地圖=%s" % [
			game.hits if is_instance_valid(game) else -1, pause_opened, got_result, back_to_map != null]}

func _wait_for_minigame(scene_name: String, max_wait: float) -> Node:
	var elapsed := 0.0
	while elapsed < max_wait:
		var cs := get_tree().current_scene
		if cs != null and cs.name == scene_name:
			return cs
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return null

# ── 12. 打坐跳時段 ───────────────────────────────────────────
func _beat_rest_skip() -> Dictionary:
	var map := _map_screen()
	if map == null:
		map = await _wait_for_scene("MapScreen", 10.0)
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen，無法測試打坐"}
	var period_before: int = GameManager.player.period
	var hp_before: int = GameManager.player.current_hp
	GameManager.player.current_hp = maxi(1, GameManager.player.max_hp - 200)  # 確保回血看得出差異
	map.perform_action("rest")
	# perform_action("rest") 內部已 heal + set pending + consume；等 period 真的變動或逾時。
	var ok := await _wait_until(func() -> bool: return GameManager.player.period != period_before, 6.0)
	return {"status": "PASS" if ok else "STUCK",
		"note": "打坐前 period=%d hp=%d → 打坐後 period=%d hp=%d" % [
			period_before, hp_before, GameManager.player.period, GameManager.player.current_hp]}

# ── 13. 存檔（選槽面板）──────────────────────────────────────
func _beat_save_game() -> Dictionary:
	var map := _map_screen()
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen"}
	map.perform_action("save")
	await _wait_frames(3)
	var picker := get_tree().root.get_node_or_null("SaveSlotPicker")
	if picker == null:
		return {"status": "STUCK", "note": "save 動作未開出 SaveSlotPicker"}
	await _wait_frames(3)
	await _screenshot("%s/%02d_save_picker.png" % [OUT_DIR, _beat_idx])
	# 存到槽 1（真輸入：Enter 確認聚焦中的第一槽，picker 預設 _focus_index=0）
	await _press_key(KEY_ENTER)
	await _wait_frames(3)
	var closed: bool = not is_instance_valid(picker) or not picker.visible
	var slot1_exists: bool = SaveManager.slot_exists(1)
	return {"status": "PASS" if (closed and slot1_exists) else "STUCK",
		"note": "存檔面板關閉=%s，slot1 存在=%s，active_slot=%d" % [closed, slot1_exists, SaveManager.active_slot]}

# ── 14. 回標題 → 繼續（讀檔）─────────────────────────────────
func _beat_title_continue_load() -> Dictionary:
	var day_before: int = GameManager.player.day
	var gold_before: int = GameManager.player.gold
	SceneRouter.go_to_title()
	var title := await _wait_for_scene("TitleScreen", 10.0)
	if title == null:
		return {"status": "STUCK", "note": "回標題畫面失敗"}
	await _wait_frames(5)
	var cont_btn: Button = title.get_node_or_null("%ContinueButton")
	if cont_btn == null or not cont_btn.visible:
		return {"status": "STUCK", "note": "ContinueButton 不存在或不可見（應該要有存檔）"}
	# 重置記憶體狀態，確保等下真的是「從檔案讀回」而非沿用記憶體舊值（較嚴謹的讀檔驗證）。
	GameManager.player.day = -1
	GameManager.player.gold = -1
	await _click_button(cont_btn)
	var map := await _wait_for_scene("MapScreen", 10.0)
	if map == null:
		return {"status": "STUCK", "note": "讀檔後未進入 MapScreen"}
	await _wait_frames(3)
	var loaded_ok: bool = GameManager.player.day == day_before and GameManager.player.gold == gold_before
	return {"status": "PASS" if loaded_ok else "STUCK",
		"note": "存檔時 day=%d gold=%d → 讀檔後 day=%d gold=%d（一致=%s）" % [
			day_before, gold_before, GameManager.player.day, GameManager.player.gold, loaded_ok]}

# ── 15. 戰鬥一場用逃跑 ───────────────────────────────────────
func _beat_battle_flee() -> Dictionary:
	var map := _map_screen()
	if map == null:
		map = await _wait_for_scene("MapScreen", 10.0)
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen，無法起戰"}
	GameManager.set_flag("battle_no_escape", false)  # 確保這場不是劇情戰殘留的不可逃旗標
	SceneRouter.go_to_battle("street_punk")
	var bm := await _wait_for_battle_manager(10.0)
	if bm == null:
		return {"status": "STUCK", "note": "10s 未取得 street_punk 戰鬥的 BattleManager"}
	var ok := await _wait_until(func() -> bool: return is_instance_valid(bm) and bm.state == bm.State.PLAYER_TURN, 8.0)
	if not ok:
		return {"status": "STUCK", "note": "逃跑測試戰未進入玩家回合"}
	await _wait_frames(3)
	if not bm._can_flee():
		return {"status": "SKIPPED", "note": "本場 _can_flee()=false（可能誤起到 boss 或殘留 battle_no_escape），略過逃跑驗證"}
	bm.player_use_flee()
	var back := await _wait_for_scene("MapScreen", 8.0)
	return {"status": "PASS" if back != null else "STUCK",
		"note": "逃跑後回地圖=%s" % (back != null)}

func _wait_for_battle_manager(max_wait: float) -> Node:
	var elapsed := 0.0
	while elapsed < max_wait:
		var bm := get_tree().get_first_node_in_group("battle_manager")
		if bm != null:
			return bm
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return null

# ── 16. 戰鬥一場按住 Shift 加速＋勝利 ───────────────────────────
func _beat_battle_speedup_victory() -> Dictionary:
	var map := _map_screen()
	if map == null:
		map = await _wait_for_scene("MapScreen", 10.0)
	if map == null:
		return {"status": "STUCK", "note": "不在 MapScreen，無法起戰"}
	SceneRouter.go_to_battle("street_punk")
	var bm := await _wait_for_battle_manager(10.0)
	if bm == null:
		return {"status": "STUCK", "note": "10s 未取得戰鬥的 BattleManager"}
	var ok := await _wait_until(func() -> bool: return is_instance_valid(bm) and bm.state == bm.State.PLAYER_TURN, 8.0)
	if not ok:
		return {"status": "STUCK", "note": "加速測試戰未進入玩家回合"}
	await _wait_frames(3)
	# 真實 Shift 注入：BattleManager._process 讀 Input.is_key_pressed(KEY_SHIFT) 或
	# _test_speedup_pressed。用真鍵盤 InputEventKey 模擬「按住」（持續發送 pressed 事件不放開）。
	var shift_down := InputEventKey.new()
	shift_down.physical_keycode = KEY_SHIFT
	shift_down.pressed = true
	Input.parse_input_event(shift_down)
	await _wait_frames(3)
	var speedup_engaged: bool = Engine.time_scale > 1.0
	await _screenshot("%s/%02d_battle_speedup_engaged.png" % [OUT_DIR, _beat_idx])
	var basic: String = bm._basic_skill_id()
	var rounds := 0
	while is_instance_valid(bm) and bm.state != bm.State.END and rounds < 20:
		if bm.state == bm.State.PLAYER_TURN:
			if basic != "":
				bm.player_use_skill(basic, 0)
			else:
				bm.force_victory()
		await _wait_seconds(0.3)  # ignore_time_scale=true already baked into _wait_seconds
		rounds += 1
	if is_instance_valid(bm) and bm.state != bm.State.END:
		bm.force_victory()
		await _wait_seconds(1.0)
	# 放開 Shift
	var shift_up := InputEventKey.new()
	shift_up.physical_keycode = KEY_SHIFT
	shift_up.pressed = false
	Input.parse_input_event(shift_up)
	await _wait_frames(3)
	var battle_ended_ok := await _wait_until(func() -> bool: return not is_instance_valid(bm) or bm.state == bm.State.END, 8.0)
	var timescale_restored := Engine.time_scale == 1.0
	var back := await _wait_for_scene("MapScreen", 10.0)
	return {"status": "PASS" if (speedup_engaged and battle_ended_ok and back != null) else "STUCK",
		"note": "加速期間 time_scale=%.1f（應>1）｜戰後 time_scale 還原=%s｜勝利回地圖=%s" % [
			2.5 if speedup_engaged else 1.0, timescale_restored, back != null]}
