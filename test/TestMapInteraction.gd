extends Node
## 驗證新互動模型：走近淡入提示（不跳選單）、多動作 NPC 按 E 進對話分流（不再跳 ActionMenu）、
## 對話選項的 menu_action 訊號會 deferred 執行對應 perform_action、離開清空。
func _ready() -> void:
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

	# 3) menu_action 訊號橋接：直接餵訊號，驗證 deferred 呼叫到 perform_action（以 save 側效果驗證）
	var save_path := "user://save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	ms._current_loc = "npc_liaochen"  # perform_action 內部只用 _current_area，位置無關，這裡維持一致性
	ms._on_dialogic_signal("menu_action:save")
	await get_tree().process_frame  # call_deferred 於下一輪 idle frame 執行
	await get_tree().process_frame
	if not FileAccess.file_exists(save_path): return _fail("menu_action:save 應 deferred 觸發存檔")

	# 4) 走近阿明（2026-07-04 起改 2 動作：支線＋常駐「再切磋一場木魚」，進 ah_ming_hub 對話分流）
	ms._on_trigger_entered("npc_ah_ming")
	if ms._current_actions.size() != 2: return _fail("阿明應 2 動作(支線+常駐木魚)，實 %d" % ms._current_actions.size())

	# 5) 離開 → 清空提示與當前點
	ms._on_trigger_exited("npc_ah_ming")
	if ms._current_loc != "": return _fail("離開應清空當前點")
	await get_tree().create_timer(0.35).timeout  # 淡出 Tween（0.2s）跑完
	if hud.prompt.visible: return _fail("離開淡出後提示應隱藏")

	print("TEST PASS: 地圖互動(走近提示淡入/多動作進對話分流/menu_action橋接/離開淡出清空) OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
