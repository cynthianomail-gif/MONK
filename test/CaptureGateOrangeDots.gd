extends Node
## windowed 截圖（驗收條件）：主線卡 c1_armory_gate 期間，前置支線（大村/水野/源造）地點
## 視為主線目標——3D 地面環＋小地圖點都要橘。截兩張：
##   _cap_gate_orange_0done_shot.png  0 完成 → 大村/水野兩環同框都橘（+小地圖）
##   _cap_gate_orange_1done_shot.png  完成大村後 → 大村環恢復原色、水野仍橘（同一次啟動內即時刷新）
## 跑法：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureGateOrangeDots.tscn -- smoke
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	GameManager.new_game()
	# 卡在 c1_armory_gate、0 完成：大村(ah_zhong)/水野(zheng_ma)/源造(lao_wang) 全候選待辦。
	GameManager.player.flags.erase("ares_purified")
	GameManager.set_flag("main_stage_ch01_ares", 4)
	GameManager.player.completed_quests = []
	GameManager.player.current_area = "shrine"
	# 站在大村(-19,-9.5)與水野(-9.5,-9.5)中間，兩個地面環同框可見，小地圖也同時可見。
	GameManager.player.last_position = {"x": -14.25, "y": 1.2, "z": -5.0}

	var s: Node = SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	for i in 90:
		await get_tree().process_frame

	# 這台自建俯瞰 Camera3D 不依賴 CameraRig（該檔目前有其他並行 agent 正在改動輸入系統，
	# 截圖不該吃到那邊的施工中狀態）——直接架在大村(-19,-9.5)/水野(-9.5,-9.5) 兩個地面環
	# 正上方往下看，乾淨拍到兩個 TorusMesh 地面環本身的顏色。
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(-14.25, 26.0, -9.5)
	cam.look_at(Vector3(-14.25, 0.0, -9.501), Vector3.FORWARD)
	cam.current = true
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img0: Image = get_viewport().get_texture().get_image()
	img0.save_png("res://_cap_gate_orange_0done_shot.png")
	print("CAP_GATE_ORANGE_0DONE_SAVED res://_cap_gate_orange_0done_shot.png ", img0.get_width(), "x", img0.get_height())

	# 完成大村 → 該點應立刻恢復原色，水野仍橘（同一次啟動內，不重進場景）。
	QuestManager._advance_quest("ah_zhong", 3, QuestManager._quests.get("ah_zhong", {}))
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png("res://_cap_gate_orange_1done_shot.png")
	print("CAP_GATE_ORANGE_1DONE_SAVED res://_cap_gate_orange_1done_shot.png ", img1.get_width(), "x", img1.get_height())

	print("CAP_GATE_ORANGE_DONE")
	get_tree().quit()
