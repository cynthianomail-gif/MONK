extends Node
## GPU 實機驗證（本輪四項 UI 改動②③）：MapHUD 左側操作提示列＋主線橘點（小地圖＋3D 地面環）。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureUiTweaks.tscn
## 輸出：
##   D:\monk\MONK\_cap_ui_hints_overview.png（地圖全景，可見左下操作提示列＋右上小地圖橘點）
##   D:\monk\MONK\_cap_ui_hints_closeup.png（玩家移到了塵旁，3D 地面環應為橘色）

const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	GameManager.new_game()
	var s: Node = SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_ui_hints_overview.png")
	print("CAP_UI_HINTS_OVERVIEW_SAVED")

	# 移到了塵（npc_liaochen，main_quest 動作）旁邊，拉近相機看地面環顏色。
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var trigger: Node = null
	for t in get_tree().get_nodes_in_group("location_trigger"):
		if String(t.location_id) == "npc_liaochen":
			trigger = t
			break
	if player != null and trigger != null:
		player.global_position = (trigger as Node3D).global_position + Vector3(0, 0, 3.0)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_ui_hints_closeup.png")
	print("CAP_UI_HINTS_CLOSEUP_SAVED")

	print("CAP_UI_HINTS_DONE")
	get_tree().quit(0)
