extends Node
## GPU 實機驗證（規格驗收條件③）：進戰鬥→開調整模式→驗證 7 個自由塊綠框 + 敵人樣板
## 琥珀框同時出現，並驗證「點綠框可拖、點琥珀不可拖」。
## headless 驗不到「GUI 渲染/命中測試」這件事本身，必須真的跑視窗版才能截圖佐證。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureLayoutTunerBattle.tscn
## 輸出：
##   D:\monk\MONK\_cap_tuner_v2_battle.png（開調整模式，全框標註：7 綠框+名牌、敵人琥珀框）
##   D:\monk\MONK\_cap_tuner_v2_drag.png（拖動綠框「玩家立繪」後的畫面，驗證位置真的變了）

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")
	for i in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 開啟調整模式（走真正的 toggle_tuning，會建 overlay + 7 綠框 + 敵人琥珀框）。
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()
	for i in 4:
		await get_tree().process_frame

	# 驗收條件②：LayoutStore.live_entries() 含 7 個 key 且各自 free==true。
	var live := LayoutStore.live_entries()
	var expect_keys := [
		"battle/player_figure", "battle/player_panel", "battle/enemy_area",
		"battle/command_host", "battle/skill_menu", "battle/combo_label", "battle/log_label",
	]
	var got_keys: Array = []
	for e in live:
		got_keys.append(e.key)
	for k in expect_keys:
		var idx: int = got_keys.find(k)
		var free_ok: bool = idx != -1 and live[idx].free == true
		print("LIVE_ENTRY_CHECK %s -> present=%s free=%s" % [k, idx != -1, live[idx].free if idx != -1 else "N/A"])
	print("LIVE_ENTRY_TOTAL_KEYS: ", got_keys)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_v2_battle.png")
	print("TUNER_V2_BATTLE_SHOT_SAVED res://_cap_tuner_v2_battle.png")

	# 點選玩家立繪（綠框，free 已登記）：驗證可被選中 + 可拖曳。
	var pf: Control = inst.ui.player_figure
	var pf_center: Vector2 = pf.get_global_rect().get_center()
	LayoutTuner._try_select(pf_center)
	var pf_selected := LayoutTuner._selected == pf
	var pf_can_drag := LayoutTuner._can_drag_selection()
	print("PLAYER_FIGURE_SELECTED: ", pf_selected, " can_drag=", pf_can_drag)

	var before_pos: Vector2 = LayoutTuner._get_pos(pf)
	# 模擬拖曳：注入一次滑鼠移動事件，位移 (60, -40)。
	var drag_target := pf_center + Vector2(60, -40)
	LayoutTuner._dragging = true
	LayoutTuner._drag_offset = before_pos - pf_center
	var motion := InputEventMouseMotion.new()
	motion.position = drag_target
	LayoutTuner._input(motion)
	await get_tree().process_frame
	var after_pos: Vector2 = LayoutTuner._get_pos(pf)
	print("PLAYER_FIGURE_DRAG: before=", before_pos, " after=", after_pos, " moved=", after_pos != before_pos)

	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_v2_drag.png")
	print("TUNER_V2_DRAG_SHOT_SAVED res://_cap_tuner_v2_drag.png")

	# 點選敵人血條（琥珀框，樣板/容器，不可拖）：驗證選中但 can_drag=false。
	var enemy_panel: Control = inst.ui._panels[0] if inst.ui._panels.size() > 0 else null
	if enemy_panel != null:
		var hp_bar: Control = enemy_panel._hp_bar
		var hp_center: Vector2 = hp_bar.get_global_rect().get_center()
		LayoutTuner._try_select(hp_center)
		var hp_selected := LayoutTuner._selected == hp_bar
		var hp_can_drag := LayoutTuner._can_drag_selection()
		print("ENEMY_HP_BAR_SELECTED: ", hp_selected, " can_drag=", hp_can_drag, " (expect false)")

		var hp_before: Vector2 = LayoutTuner._get_pos(hp_bar)
		LayoutTuner._dragging = true
		LayoutTuner._drag_offset = hp_before - hp_center
		var motion2 := InputEventMouseMotion.new()
		motion2.position = hp_center + Vector2(50, 50)
		LayoutTuner._input(motion2)
		await get_tree().process_frame
		var hp_after: Vector2 = LayoutTuner._get_pos(hp_bar)
		print("ENEMY_HP_BAR_DRAG_BLOCKED: before=", hp_before, " after=", hp_after, " unchanged=", hp_after == hp_before)

	print("CAPTURE_TUNER_V2_BATTLE_DONE")
	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit(0)
