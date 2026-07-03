extends Node
## 現況擷取：戰鬥技能子選單「現在長什麼樣」，供美術改版提案用（僅擺拍截圖，不改任何 src/ 程式）。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSkillMenuMockCurrent.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	await _capture_current_skill_menu()

	print("CAPTURE_SKILLMENU_CURRENT_DONE")
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

## 現況技能子選單：讓資源充足（karma/merit 給滿）以免技能被灰置，如實呈現現有樣式
## （純文字 Button 列表：技能名＋括號消耗，description 只在 tooltip，無屬性圖示、無選中放大）。
func _capture_current_skill_menu() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")
	for i in 24:
		await get_tree().process_frame
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	# 直接呼叫現有 UI API 開技能子選單（擺拍，不經真實輸入），用苦行職五招呈現消耗種類差異。
	inst.ui.show_skill_menu(["basic_punch", "arhat_strike", "vajra_glare", "ascetic_temper", "iron_shirt"])
	for i in 10:
		await get_tree().process_frame
	await _save(svc, "res://_skillmenu_current.png")
	await _free_viewport(svc)
