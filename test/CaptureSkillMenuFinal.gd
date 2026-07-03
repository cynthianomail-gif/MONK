extends Node
## 正式驗收擷取：戰鬥技能子選單改版後（候選 A 直列卡片）實裝於 BattleUI 的真實畫面。
## 呼叫 show_skill_menu() 走正式 src/ 程式碼，不是 mockup 擺拍腳本。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSkillMenuFinal.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	await _capture_final_skill_menu()

	print("CAPTURE_SKILLMENU_FINAL_DONE")
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

## 正式技能子選單：資源給滿避免技能被灰置，如實呈現候選 A 卡片樣式＋選中態（第 3 項金剛怒目）。
func _capture_final_skill_menu() -> void:
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
	# 直接呼叫正式 UI API 開技能子選單（擺拍，不經真實輸入），用苦行職五招呈現消耗種類差異。
	inst.ui.show_skill_menu(["basic_punch", "arhat_strike", "vajra_glare", "ascetic_temper", "iron_shirt"])
	# 手動移動選中到第 3 項（金剛怒目），與 mockup A 決策圖一致，展示選中態視覺。
	inst.ui._skill_selected = 2
	inst.ui._refresh_skill_cards()
	for i in 10:
		await get_tree().process_frame
	await _save(svc, "res://_skillmenu_final.png")
	await _free_viewport(svc)
