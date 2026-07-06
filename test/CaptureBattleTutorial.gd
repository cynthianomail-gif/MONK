extends Node
## 擷取教學小視窗（BattleTutorial）實際顯示畫面，供使用者過目。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureBattleTutorial.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	await _capture_point("intro", "res://_cap_tutorial_intro.png")
	await _capture_point("weakness", "res://_cap_tutorial_weakness.png")
	await _capture_point("victory", "res://_cap_tutorial_victory.png")

	print("CAPTURE_BATTLE_TUTORIAL_DONE")
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

## 擺拍：進教學戰、放行 setup() 內建自動播放的 intro 點（真實觸發時機），截下畫面；
## 其餘要展示的點改用直接呼叫 tutorial.show_point(point_id)（不 await）擺拍，
## 因為它們的真實觸發時機（打中弱點/敵人出招前）需要完整跑一輪回合，擺拍只需要畫面本身。
func _capture_point(point_id: String, out_path: String) -> void:
	GameManager.set_flag("tutorial_battle", true)
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame

	if point_id == "intro":
		inst.setup("tutorial_punk")  # setup() 內部 await show_point("intro")，此時畫面正是要擺拍的
		for i in 20:
			await get_tree().process_frame
			if inst.tutorial.visible:
				break
	else:
		inst.tutorial._shown["intro"] = true  # 跳過 intro 自動播放，避免卡住
		inst.setup("tutorial_punk")
		for i in 10:
			await get_tree().process_frame
		inst.tutorial.show_point(point_id)  # 不 await：擺拍只需要它把畫面顯示出來
		for i in 15:
			await get_tree().process_frame

	await _save(svc, out_path)

	# 收尾：關掉小窗避免卡在 await 迴圈，才能安全釋放場景。
	inst.tutorial.inject_confirm()
	for i in 10:
		await get_tree().process_frame
	GameManager.set_flag("tutorial_battle", false)
	await _free_viewport(svc)
