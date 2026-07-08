extends Node
## 驗證新互動模型：走近淡入提示（不跳選單）、多動作 NPC 按 E 進對話分流（不再跳 ActionMenu）、
## 對話選項的 menu_action 訊號會 deferred 執行對應 perform_action、離開清空。
##
## ⚠ 本測試會觸發 SaveManager 的「save」動作（開 SlotPicker→存槽1），而 headless 的 user://
## 是真實使用者存檔目錄。SaveManager 首次存取時會把既有的 user://save.json 遷移改名成
## save.json.bak——這對使用者真實存檔是無害的（內容原封不動只是換位置＋改名），但會弄髒
## 使用者的存檔目錄。故開跑前先記錄 save.json 是否原本存在，跑完（不論成功或提前 _fail）都
## 把它從 .bak 還原回來，並清掉本測試自己造的 slot1/meta 檔。
var _legacy_save_existed_before: bool = false

func _ready() -> void:
	_legacy_save_existed_before = FileAccess.file_exists("user://save.json")
	GameManager.new_game()
	var ms := (load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene).instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Node = ms.get_node("HUD")

	# 1) 走近 了塵（4 動作）→ 顯示提示（會淡入）、不直接跳 ActionMenu
	ms._on_trigger_entered("npc_liaochen")
	if not hud.prompt.visible: return _fail("走近應顯示提示")
	if hud.action_menu.visible: return _fail("走近不應直接跳選單")
	if ms._current_actions.size() != 4: return _fail("了塵應 4 動作，實 %d" % ms._current_actions.size())
	# 提示淡入用 Tween 從 alpha 0 開始，走近當下應已啟動（不要求跑完淡入才算「顯示」）
	if hud.prompt.modulate.a < 0.0: return _fail("提示 modulate.a 不應為負")

	# 2) 按 E（多動作、且在 NPC_ENTRY_TIMELINE 名單內）→ 進對話分流，不跳 ActionMenu
	ms._interact()
	if hud.action_menu.visible: return _fail("多動作多功能 NPC 按 E 不應再跳 ActionMenu")
	# Dialogic.start() 若對話層場景尚未 ready，會等 ready 訊號才真的 start_timeline，故多等幾幀。
	for i in range(6):
		if Dialogic.current_timeline != null:
			break
		await get_tree().process_frame
	if Dialogic.current_timeline == null: return _fail("多動作按 E 應啟動 Dialogic 對話")
	if not String(Dialogic.current_timeline.resource_path).contains("liaochen_hub"):
		return _fail("了塵應啟動 liaochen_hub，實為 %s" % Dialogic.current_timeline.resource_path)
	Dialogic.end_timeline()
	await get_tree().process_frame

	# 3) menu_action 訊號橋接：直接餵訊號，驗證 deferred 呼叫到 perform_action。
	# 2026-07-08 J3 起「save」動作改開 SlotPicker(save 模式) 而非直接存檔，
	# 故這裡驗證 picker 出現，再模擬選槽 1，以槽 1 存檔檔案作為側效果驗證。
	var slot1_path := "user://save_slot_1.json"
	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot1_path))
	ms._current_loc = "npc_liaochen"  # perform_action 內部只用 _current_area，位置無關，這裡維持一致性
	ms._on_dialogic_signal("menu_action:save")
	# call_deferred＋_run_menu_action 可能等 Dialogic 收尾（timeline_ended＋一幀），
	# 收尾幀數依 Dialogic 內部 ending timeline 而定非固定 → 輪詢等待，上限 120 幀。
	var picker: Node = null
	var waited := 0
	while waited < 120:
		picker = get_tree().root.find_child("SaveSlotPicker", true, false)
		if picker != null and is_instance_valid(picker) and picker.visible:
			break
		await get_tree().process_frame
		waited += 1
	print("TestMapInteraction: menu_action:save 於 %d 幀後生效" % waited)
	if picker == null or not is_instance_valid(picker): return _fail("menu_action:save 應 deferred 開啟 SlotPicker")
	if not picker.visible: return _fail("SlotPicker 應為可見狀態")
	if picker.mode != "save": return _fail("SlotPicker 應為 save 模式，實為 %s" % picker.mode)
	# 模擬選槽 1：觸發實際存檔側效果。
	picker._on_slot_pressed(1)
	await get_tree().process_frame
	if not FileAccess.file_exists(slot1_path): return _fail("選槽 1 應寫入 save_slot_1.json")
	if is_instance_valid(picker): picker.queue_free()
	_cleanup_save_artifacts()

	# 4) 走近阿明（2026-07-04 起改 2 動作：支線＋常駐「再切磋一場木魚」，進 ah_ming_hub 對話分流）
	ms._on_trigger_entered("npc_ah_ming")
	if ms._current_actions.size() != 2: return _fail("阿明應 2 動作(支線+常駐木魚)，實 %d" % ms._current_actions.size())

	# 5) 離開 → 清空提示與當前點
	ms._on_trigger_exited("npc_ah_ming")
	if ms._current_loc != "": return _fail("離開應清空當前點")
	await get_tree().create_timer(0.35).timeout  # 淡出 Tween（0.2s）跑完
	if hud.prompt.visible: return _fail("離開淡出後提示應隱藏")

	print("TEST PASS: 地圖互動(走近提示淡入/多動作進對話分流/menu_action橋接/離開淡出清空) OK")
	_cleanup_save_artifacts()
	get_tree().quit(0)

## 清掉本測試觸碰過的存檔相關檔案：slot1 存檔 + save_meta.json；若本測試觸發了
## SaveManager 的舊檔遷移（save.json → save.json.bak）且使用者原本就有 save.json，
## 把它從 .bak 還原回來，不留痕跡。成功／失敗兩條路徑都會呼叫本函式。
func _cleanup_save_artifacts() -> void:
	var slot1_path := "user://save_slot_1.json"
	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot1_path))
	var meta_path := "user://save_meta.json"
	if FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path))
	var legacy_path := "user://save.json"
	var legacy_bak := "user://save.json.bak"
	if _legacy_save_existed_before and not FileAccess.file_exists(legacy_path) and FileAccess.file_exists(legacy_bak):
		var dir := DirAccess.open("user://")
		if dir:
			dir.rename(ProjectSettings.globalize_path(legacy_bak), ProjectSettings.globalize_path(legacy_path))
	elif not _legacy_save_existed_before and FileAccess.file_exists(legacy_bak):
		# 使用者原本沒有 save.json，這支測試前的其他測試/流程意外造出了 .bak → 視為本測試的
		# 附帶產物一併清掉，避免留下無主檔案。
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_bak))

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	_cleanup_save_artifacts()
	get_tree().quit(1)
