extends Node
## 修行盤曼荼羅法輪盤 GPU 截圖驗收（2026-07-07 重製）。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureBoardMandala.tscn

const BOARD_APP := "res://src/ui/menu/pages/BoardApp.gd"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	await _capture_full()
	await _capture_selected()

	print("CAPTURE_BOARD_MANDALA_DONE")
	get_tree().quit(0)

func _new_viewport() -> SubViewport:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	return svc

func _save(svc: SubViewport, out_path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png(out_path)
	print("SAVED ", out_path)

func _free_viewport(svc: SubViewport) -> void:
	svc.queue_free()
	await get_tree().process_frame

## 1) 全盤四態：解鎖多節點（含深入鏈條、匯流被動、師鎖環）湊出「已解鎖/可解鎖/未達前置/劇情鎖」
## 四態同時入鏡＋四脈直線放射＋滿版置中。
func _capture_full() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	CultivationBoard.reload()
	GameManager.player["board_unlocked"] = ["core"]
	GameManager.add_daoxing(20000)
	# 沿 atk 鏈解鎖到 atk_3（製造「已解鎖」縱深，其餘鏈條僅解 _1 讓 available/locked 都可見）。
	for nid in ["atk_1", "atk_2", "atk_3"]:
		if CultivationBoard.can_unlock(nid):
			CultivationBoard.unlock_node(nid)
	for nid in ["def_1", "hp_1", "spd_1"]:
		if CultivationBoard.can_unlock(nid):
			CultivationBoard.unlock_node(nid)
	var app: Control = (load(BOARD_APP) as GDScript).new()
	svc.add_child(app)
	# app 是 Control(FULL_RECT anchors)，直接掛在 SubViewport 下不會自動撐滿——
	# 需手動指定 size 才能觸發容器一路往下正確 expand（_board_holder 才拿得到真實尺寸算 scale）。
	app.size = Vector2(svc.size)
	await get_tree().process_frame
	for i in 12:
		await get_tree().process_frame
	await _save(svc, "res://_cap_board_v2_full.png")
	await _free_viewport(svc)

## 2) 選中一個可解鎖技能節點（skill_vajra_fist，菱形節點）含詳情面板：類型 badge/名稱/描述/
## 花費/前置達成清單/充能提示/圖例。
func _capture_selected() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	CultivationBoard.reload()
	GameManager.player["board_unlocked"] = ["core"]
	GameManager.add_daoxing(20000)
	if CultivationBoard.can_unlock("atk_1"):
		CultivationBoard.unlock_node("atk_1")
	var app: Control = (load(BOARD_APP) as GDScript).new()
	svc.add_child(app)
	app.size = Vector2(svc.size)
	await get_tree().process_frame
	app.select_node("skill_vajra_fist")  # available 態技能節點，右側面板顯示內容
	for i in 6:
		await get_tree().process_frame
	await _save(svc, "res://_cap_board_v2_selected.png")
	await _free_viewport(svc)
